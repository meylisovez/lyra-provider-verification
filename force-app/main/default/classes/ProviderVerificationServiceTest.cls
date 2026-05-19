@IsTest
private class ProviderVerificationServiceTest {

    @IsTest
    static void lowRiskFlow() {
        Provider_Application__c application = newApplication(
            'John',
            'Doe',
            'john@test.com',
            '1234567897'
        );

        Test.startTest();
        insert application;
        Test.stopTest();

        application = [
            SELECT Status__c, Risk_Tier__c
            FROM Provider_Application__c
            WHERE Id = :application.Id
        ];

        System.assertEquals('Verified', application.Status__c);
        System.assertEquals('Low', application.Risk_Tier__c);

        Account account = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'John Doe'
            LIMIT 1
        ];

        Contact contact = [
            SELECT Id, Email, AccountId
            FROM Contact
            WHERE Email = 'john@test.com'
            LIMIT 1
        ];

        System.assertEquals(account.Id, contact.AccountId);
    }

    @IsTest
    static void highRiskFlow() {
        Provider_Application__c application = newApplication(
            'Mike',
            'Smith',
            'mike@test.com',
            '1234567892'
        );

        Test.startTest();
        insert application;
        Test.stopTest();

        application = [
            SELECT Status__c, Risk_Tier__c
            FROM Provider_Application__c
            WHERE Id = :application.Id
        ];

        System.assertEquals('Verified', application.Status__c);
        System.assertEquals('High', application.Risk_Tier__c);

        List<Compliance_Task__c> tasks = [
            SELECT Id, Status__c, Provider_Application__c
            FROM Compliance_Task__c
            WHERE Provider_Application__c = :application.Id
        ];

        System.assertEquals(1, tasks.size());
        System.assertEquals('New', tasks[0].Status__c);
    }

    @IsTest
    static void failedVerification() {
        Provider_Application__c application = newApplication(
            'Error',
            'Case',
            'error@test.com',
            '1234567800'
        );

        Test.startTest();
        insert application;
        Test.stopTest();

        application = [
            SELECT Status__c
            FROM Provider_Application__c
            WHERE Id = :application.Id
        ];

        System.assertEquals('Failed', application.Status__c);

        List<Error_Log__c> logs = [
            SELECT Id, Error_Type__c, Status__c
            FROM Error_Log__c
            WHERE Related_Record_Id__c = :String.valueOf(application.Id)
        ];

        System.assertEquals(1, logs.size());
        System.assertEquals('Integration', logs[0].Error_Type__c);
        System.assertEquals('Open', logs[0].Status__c);
    }
    @IsTest
    static void buildsDmlErrorLogs() {
        Account account = new Account();
        Database.SaveResult result = Database.insert(account, false);

        List<Error_Log__c> logs = new List<Error_Log__c>();
        ProviderVerificationService.VerificationWork work =
            new ProviderVerificationService.VerificationWork();

        ProviderVerificationService.addDmlErrorsToLog(
            work,
            UserInfo.getUserId(),
            'Account insert failed',
            result.getErrors()
        );

        System.assertEquals(1, work.logsToInsert.size());
        System.assertEquals('DML', work.logsToInsert[0].Error_Type__c);
        System.assertEquals('Open', work.logsToInsert[0].Status__c);
    }          

    private static Provider_Application__c newApplication(
        String firstName,
        String lastName,
        String email,
        String npiNumber
    ) {
        return new Provider_Application__c(
            First_Name__c = firstName,
            Last_Name__c = lastName,
            Email__c = email,
            NPI_Number__c = npiNumber
        );
    }
}