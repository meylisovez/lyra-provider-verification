trigger ProviderApplicationTrigger on Provider_Application__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        ProviderApplicationTriggerHandler.enqueueVerification(
            Trigger.newMap.keySet()
        );
    }
}