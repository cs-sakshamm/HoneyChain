import { IRegistrationProvider, RegistrationAuthority, RegistrationVerificationResult } from './types';

export class OtherLocalProvider implements IRegistrationProvider {
  public readonly authority: RegistrationAuthority = 'OTHER_LOCAL';
  public readonly authorityName = 'Other / Local Registration';
  public readonly supportsAutomatedVerification = false;

  /**
   * For local / regional / other associations that do not offer a public automated API gateway.
   * Does NOT fake automated verification. Explicitly marks record as 'Manual Verification Required'.
   */
  async verifyRegistration(registrationIdRaw: string): Promise<RegistrationVerificationResult> {
    const regId = (registrationIdRaw || '').trim().toUpperCase();

    if (!regId || regId.length < 3) {
      return {
        success: false,
        status: 'Failed',
        authority: this.authority,
        registrationId: regId,
        authorityName: this.authorityName,
        message: 'Registration ID must be at least 3 characters.',
        requiresManualReview: false
      };
    }

    return {
      success: true,
      status: 'Manual Verification Required',
      authority: this.authority,
      registrationId: regId,
      authorityName: this.authorityName,
      message: 'Verification unavailable — manual verification required.',
      requiresManualReview: true,
      metadata: {
        verifiedVia: 'Manual Association Review Queue',
        registryType: 'OTHER_LOCAL'
      }
    };
  }
}
