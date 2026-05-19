trigger VerificationEventTrigger on Verification_Event__e (after insert) {
    VerificationEventTriggerHandler.createComplianceTasks(Trigger.new);
}