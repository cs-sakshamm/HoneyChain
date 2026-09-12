import {
  IRegistrationProvider,
  RegistrationAuthority,
  RegistrationVerificationResult,
  RegistrationVerificationStatus
} from './types';
import { StateAgricultureProvider } from './stateAgricultureProvider';
import { NationalHoneyProducersProvider } from './nationalHoneyProducersProvider';
import { OrganicCertificationBoardProvider } from './organicCertificationBoardProvider';
import { OtherLocalProvider } from './otherLocalProvider';

export class RegistrationProviderFactory {
  private static providers: Map<RegistrationAuthority, IRegistrationProvider> = new Map<RegistrationAuthority, IRegistrationProvider>([
    ['STATE_AGRICULTURE', new StateAgricultureProvider()],
    ['NATIONAL_HONEY_PRODUCERS', new NationalHoneyProducersProvider()],
    ['ORGANIC_CERTIFICATION_BOARD', new OrganicCertificationBoardProvider()],
    ['OTHER_LOCAL', new OtherLocalProvider()]
  ]);

  /**
   * Normalize input authority string to strongly typed RegistrationAuthority enum
   */
  public static normalizeAuthority(authorityRaw?: string): RegistrationAuthority {
    if (!authorityRaw) return 'STATE_AGRICULTURE';
    const norm = authorityRaw.toUpperCase().trim().replace(/[-\s]/g, '_');

    if (norm.includes('AGRICULTURE') || norm === 'STATE_REGISTRY' || norm === 'STATE_AGRICULTURE') {
      return 'STATE_AGRICULTURE';
    }
    if (norm.includes('PRODUCERS') || norm.includes('NATIONAL') || norm === 'COOPERATIVE' || norm === 'NATIONAL_HONEY_PRODUCERS') {
      return 'NATIONAL_HONEY_PRODUCERS';
    }
    if (norm.includes('ORGANIC') || norm.includes('APICULTURE') || norm === 'APICULTURE_BOARD' || norm === 'ORGANIC_CERTIFICATION_BOARD') {
      return 'ORGANIC_CERTIFICATION_BOARD';
    }
    return 'OTHER_LOCAL';
  }

  /**
   * Get provider instance for authority
   */
  public static getProvider(authorityRaw?: string): IRegistrationProvider {
    const authority = this.normalizeAuthority(authorityRaw);
    const provider = this.providers.get(authority);
    if (!provider) {
      return new OtherLocalProvider();
    }
    return provider;
  }

  /**
   * Execute registration verification via appropriate authority provider
   */
  public static async verifyRegistration(
    registrationId: string,
    authorityRaw?: string
  ): Promise<RegistrationVerificationResult> {
    const provider = this.getProvider(authorityRaw);
    return provider.verifyRegistration(registrationId);
  }
}
