export type RegistrationAuthority =
  | 'STATE_AGRICULTURE'
  | 'NATIONAL_HONEY_PRODUCERS'
  | 'ORGANIC_CERTIFICATION_BOARD'
  | 'OTHER_LOCAL';

export type RegistrationVerificationStatus =
  | 'Verified'
  | 'Manual Verification Required'
  | 'Failed'
  | 'Pending'
  | 'Not Started';

export interface RegistrationVerificationResult {
  success: boolean;
  status: RegistrationVerificationStatus;
  authority: RegistrationAuthority;
  registrationId: string;
  authorityName: string;
  message: string;
  requiresManualReview: boolean;
  verifiedAt?: Date;
  metadata?: Record<string, any>;
}

export interface IRegistrationProvider {
  readonly authority: RegistrationAuthority;
  readonly authorityName: string;
  readonly supportsAutomatedVerification: boolean;

  verifyRegistration(registrationId: string): Promise<RegistrationVerificationResult>;
}
