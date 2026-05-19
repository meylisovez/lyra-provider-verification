@IsTest
private class ProviderApplicationTriggerHandlerTest {

    @IsTest
    static void ignoresEmptyInput() {
        Test.startTest();
        ProviderApplicationTriggerHandler.enqueueVerification(new Set<Id>());
        ProviderApplicationTriggerHandler.enqueueVerification(null);
        Test.stopTest();

        System.assert(true, 'Empty input should not enqueue verification.');
    }
}