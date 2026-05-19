public without sharing class ProviderApplicationTriggerHandler {

    public static void enqueueVerification(Set<Id> applicationIds) {
        if (applicationIds == null || applicationIds.isEmpty()) {
            return;
        }

        System.enqueueJob(
            new ProviderVerificationQueueable(applicationIds)
        );
    }
}