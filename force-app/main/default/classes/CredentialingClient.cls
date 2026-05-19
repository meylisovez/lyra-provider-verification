public without sharing class CredentialingClient {

    private static final String LOW_RISK = 'Low Risk';
    private static final String HIGH_RISK = 'High Risk';

    public CredentialingResponse verifyNpi(String npiNumber) {
        if (isFailureNpi(npiNumber)) {
            throw new CredentialingException(
                'Credentialing service unavailable'
            );
        }

        if (isLowRiskNpi(npiNumber)) {
            return buildResponse('V-100', LOW_RISK, true);
        }

        return buildResponse('V-200', HIGH_RISK, false);
    }

    private Boolean isLowRiskNpi(String npiNumber) {
        return '13579'.contains(npiNumber.right(1));
    }

    private Boolean isFailureNpi(String npiNumber) {
        return npiNumber.endsWith('00');
    }

    private CredentialingResponse buildResponse(
        String verificationId,
        String riskCategory,
        Boolean licenseActive
    ) {
        CredentialingResponse response = new CredentialingResponse();

        response.verificationId = verificationId;
        response.riskCategory = riskCategory;
        response.licenseActive = licenseActive;

        return response;
    }

    public class CredentialingException extends Exception {}
}