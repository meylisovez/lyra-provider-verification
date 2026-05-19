public without sharing class ProviderVerificationQueueable implements Queueable, Database.AllowsCallouts {

    private final Set<Id> applicationIds;

    public ProviderVerificationQueueable(Set<Id> applicationIds) {
        this.applicationIds = applicationIds;
    }

    public void execute(QueueableContext context) {
        List<Provider_Application__c> applications = getApplications();
        ProviderVerificationService.verify(applications);
    }

    private List<Provider_Application__c> getApplications() {
        return [
            SELECT Id, First_Name__c, Last_Name__c, Email__c, NPI_Number__c, Status__c
            FROM Provider_Application__c
            WHERE Id IN :applicationIds
        ];
    }
}