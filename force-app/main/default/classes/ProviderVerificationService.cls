public without sharing class ProviderVerificationService {

    private static final String LOW_RISK = 'Low Risk';
    private static final String HIGH_RISK = 'High Risk';
    private static final String SOURCE = 'Provider Verification';
    private static final String ERROR_TYPE_INTEGRATION = 'Integration';
    private static final String ERROR_TYPE_DML = 'DML';

    public static void verify(List<Provider_Application__c> applications) {
        CredentialingClient client = new CredentialingClient();
        VerificationWork work = new VerificationWork();

        for (Provider_Application__c application : applications) {
            verifyOne(application, client, work);
        }

        saveWork(work);
    }

    private static void verifyOne(
        Provider_Application__c application,
        CredentialingClient client,
        VerificationWork work
    ) {
        try {
            CredentialingResponse response =
                client.verifyNpi(application.NPI_Number__c);

            applyVerificationResult(application, response, work);
        } catch (Exception ex) {
            markFailed(application, ex, work);
        }

        work.applicationsToUpdate.add(application);
    }

    private static void applyVerificationResult(
        Provider_Application__c application,
        CredentialingResponse response,
        VerificationWork work
    ) {
        application.Status__c = 'Verified';
        application.Risk_Tier__c = getRiskTier(response);

        if (response.riskCategory == LOW_RISK) {
            addProviderRecords(application, work);
            return;
        }

        if (response.riskCategory == HIGH_RISK) {
            addVerificationEvent(application, work);
        }
    }

    private static String getRiskTier(CredentialingResponse response) {
        return response.riskCategory == LOW_RISK ? 'Low' : 'High';
    }

    private static void addProviderRecords(
        Provider_Application__c application,
        VerificationWork work
    ) {
        Account account = new Account(
            Name = application.First_Name__c + ' ' + application.Last_Name__c
        );

        Contact contact = new Contact(
            FirstName = application.First_Name__c,
            LastName = application.Last_Name__c,
            Email = application.Email__c
        );

        work.accountsToInsert.add(account);
        work.contactsToInsert.add(contact);
        work.lowRiskApplicationIds.add(application.Id);
    }

    private static void addVerificationEvent(
        Provider_Application__c application,
        VerificationWork work
    ) {
        work.eventsToPublish.add(new Verification_Event__e(
            Provider_Application_Id__c = String.valueOf(application.Id),
            Risk_Tier__c = 'High',
            Message__c = 'High risk provider application requires manual compliance review.'
        ));
    }

    private static void markFailed(
        Provider_Application__c application,
        Exception ex,
        VerificationWork work
    ) {
        application.Status__c = 'Failed';

        work.logsToInsert.add(new Error_Log__c(
            Source__c = SOURCE,
            Error_Type__c = ERROR_TYPE_INTEGRATION,
            Related_Record_Id__c = String.valueOf(application.Id),
            Status__c = 'Open',
            Message__c = ex.getMessage(),
            Stack_Trace__c = ex.getStackTraceString()
        ));
    }

    private static void saveWork(VerificationWork work) {
        saveLowRiskProviders(work);
        publishHighRiskEvents(work);

        Database.SaveResult[] applicationResults =
            Database.update(work.applicationsToUpdate, false);

        for (Integer i = 0; i < applicationResults.size(); i++) {
            if (!applicationResults[i].isSuccess()) {
                addDmlErrorsToLog(
                    work,
                    work.applicationsToUpdate[i].Id,
                    'Provider application update failed',
                    applicationResults[i].getErrors()
                );
            }
        }

        if (!work.logsToInsert.isEmpty()) {
            Database.insert(work.logsToInsert, false);
        }
    }

    private static void saveLowRiskProviders(VerificationWork work) {
        Database.SaveResult[] accountResults =
            Database.insert(work.accountsToInsert, false);

        for (Integer i = 0; i < accountResults.size(); i++) {
            Id applicationId = work.lowRiskApplicationIds[i];

            if (accountResults[i].isSuccess()) {
                work.contactsToInsert[i].AccountId = accountResults[i].getId();
            } else {
                addDmlErrorsToLog(
                    work,
                    applicationId,
                    'Account insert failed',
                    accountResults[i].getErrors()
                );
            }
        }

        Database.SaveResult[] contactResults =
            Database.insert(work.contactsToInsert, false);

        for (Integer i = 0; i < contactResults.size(); i++) {
            if (!contactResults[i].isSuccess()) {
                addDmlErrorsToLog(
                    work,
                    work.lowRiskApplicationIds[i],
                    'Contact insert failed',
                    contactResults[i].getErrors()
                );
            }
        }
    }
    @TestVisible
    private static void addDmlErrorsToLog(
        VerificationWork work,
        Id relatedRecordId,
        String context,
        Database.Error[] errors
    ) {
        for (Database.Error error : errors) {
            work.logsToInsert.add(new Error_Log__c(
                Source__c = SOURCE,
                Error_Type__c = ERROR_TYPE_DML,
                Related_Record_Id__c = String.valueOf(relatedRecordId),
                Status__c = 'Open',
                Message__c = context + ': ' + error.getMessage()
            ));
        }
    }

    private static void publishHighRiskEvents(VerificationWork work) {
        if (!work.eventsToPublish.isEmpty()) {
            EventBus.publish(work.eventsToPublish);
        }
    }
    @TestVisible
    private class VerificationWork {
        List<Provider_Application__c> applicationsToUpdate =
            new List<Provider_Application__c>();

        List<Account> accountsToInsert = new List<Account>();
        List<Contact> contactsToInsert = new List<Contact>();
        List<Id> lowRiskApplicationIds = new List<Id>();

        List<Verification_Event__e> eventsToPublish =
            new List<Verification_Event__e>();
        @TestVisible
        List<Error_Log__c> logsToInsert =
            new List<Error_Log__c>();
    }
}