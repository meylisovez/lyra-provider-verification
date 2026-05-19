@IsTest
private class VerificationEventTriggerHandlerTest {

    @IsTest
    static void createsTaskForHighRiskEvent() {
        Provider_Application__c application = newApplication();
        insert application;

        Test.startTest();

        EventBus.publish(new Verification_Event__e(
            Provider_Application_Id__c = String.valueOf(application.Id),
            Risk_Tier__c = 'High',
            Message__c = 'High risk provider application requires manual compliance review.'
        ));

        Test.stopTest();

        Compliance_Task__c task = [
            SELECT Id, Subject__c, Status__c, OwnerId, Provider_Application__c
            FROM Compliance_Task__c
            WHERE Provider_Application__c = :application.Id
            LIMIT 1
        ];

        System.assertEquals('Manual compliance review required', task.Subject__c);
        System.assertEquals('New', task.Status__c);
        System.assertEquals(application.Id, task.Provider_Application__c);

        Group queue = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = 'Compliance_Review_Queue'
            LIMIT 1
        ];

        System.assertEquals(queue.Id, task.OwnerId);
    }

    private static Provider_Application__c newApplication() {
        return new Provider_Application__c(
            First_Name__c = 'High',
            Last_Name__c = 'Risk',
            Email__c = 'highrisk@test.com',
            NPI_Number__c = '1234567892'
        );
    }
    @IsTest
    static void buildsErrorLogs() {
        Compliance_Task__c task = new Compliance_Task__c(
            Subject__c = 'Bad task',
            Status__c = 'New',
            Provider_Application__c = UserInfo.getUserId()
        );

        Database.SaveResult result = Database.insert(task, false);

        List<Error_Log__c> logs = new List<Error_Log__c>();

        VerificationEventTriggerHandler.addDmlErrorsToLog(
            logs,
            UserInfo.getUserId(),
            'Compliance task insert failed',
            result.getErrors()
        );

        System.assertEquals(1, logs.size());
        System.assertEquals('DML', logs[0].Error_Type__c);
        System.assertEquals('Open', logs[0].Status__c);
        System.assert(
            logs[0].Message__c.contains('Compliance task insert failed')
        );
    }
}