public without sharing class VerificationEventTriggerHandler {

    private static final String SOURCE = 'Compliance Task Creation';
    private static final String ERROR_TYPE_DML = 'DML';
    private static final String COMPLIANCE_QUEUE = 'Compliance_Review_Queue';

    public static void createComplianceTasks(List<Verification_Event__e> events) {
        Id queueId = getComplianceQueueId();
        List<Compliance_Task__c> tasks = new List<Compliance_Task__c>();

        for (Verification_Event__e eventRecord : events) {
            tasks.add(buildTask(eventRecord, queueId));
        }

        saveTasks(tasks);
    }

    private static Compliance_Task__c buildTask(
        Verification_Event__e eventRecord,
        Id queueId
    ) {
        return new Compliance_Task__c(
            Subject__c = 'Manual compliance review required',
            Provider_Application__c =
                (Id) eventRecord.Provider_Application_Id__c,
            Status__c = 'New',
            OwnerId = queueId
        );
    }

    private static void saveTasks(List<Compliance_Task__c> tasks) {
        Database.SaveResult[] taskResults =
            Database.insert(tasks, false);

        List<Error_Log__c> logsToInsert = new List<Error_Log__c>();

        for (Integer i = 0; i < taskResults.size(); i++) {
            if (!taskResults[i].isSuccess()) {
                addDmlErrorsToLog(
                    logsToInsert,
                    tasks[i].Provider_Application__c,
                    'Compliance task insert failed',
                    taskResults[i].getErrors()
                );
            }
        }

        if (!logsToInsert.isEmpty()) {
            Database.insert(logsToInsert, false);
        }
    }
    @TestVisible
    private static void addDmlErrorsToLog(
        List<Error_Log__c> logsToInsert,
        Id relatedRecordId,
        String context,
        Database.Error[] errors
    ) {
        for (Database.Error error : errors) {
            logsToInsert.add(new Error_Log__c(
                Source__c = SOURCE,
                Error_Type__c = ERROR_TYPE_DML,
                Related_Record_Id__c = String.valueOf(relatedRecordId),
                Status__c = 'Open',
                Message__c = context + ': ' + error.getMessage()
            ));
        }
    }

    private static Id getComplianceQueueId() {
        return [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = :COMPLIANCE_QUEUE
            LIMIT 1
        ].Id;
    }
}