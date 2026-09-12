/**
 * Profile completion validation service for HoneyChain.
 * Determines whether a user's required profile information is complete
 * based on their supply chain role.
 */

export function normalizeUserRole(role?: string): string {
  if (!role) return 'HARVESTER';
  const r = role.toUpperCase().trim();
  if (
    r === 'COLLECTION' ||
    r === 'PROCESSOR' ||
    r === 'COLLECTION_PROCESSING' ||
    r === 'COLLECTOR_PROCESSOR'
  ) {
    return 'COLLECTOR_PROCESSOR';
  }
  if (r === 'LAB' || r === 'LAB_TESTING') return 'LAB';
  if (r === 'PACKAGING' || r === 'PACKAGER') return 'PACKAGING';
  if (r === 'ADMIN') return 'ADMIN';
  return 'HARVESTER';
}

/**
 * Validates whether the user's stored profile in PostgreSQL satisfies the mandatory
 * completion requirements for their role.
 */
export function isUserProfileComplete(user: any): boolean {
  if (!user) return false;

  const nameOk = Boolean(
    user.name &&
      typeof user.name === 'string' &&
      user.name.trim().length > 0 &&
      user.name.trim().toLowerCase() !== 'unknown'
  );

  const emailOk = Boolean(
    user.email &&
      typeof user.email === 'string' &&
      user.email.trim().length > 0 &&
      !user.email.includes('anonymous')
  );

  const phoneOk = Boolean(
    user.phone &&
      typeof user.phone === 'string' &&
      user.phone.trim().length > 0
  );

  const role = normalizeUserRole(user.role);

  // 1. Harvester: Requires full name, valid email, and contact phone number
  if (role === 'HARVESTER') {
    return nameOk && emailOk && phoneOk;
  }

  // 2. Collection & Processing: Requires name, contact, organization, facility location, and license/registration
  if (role === 'COLLECTOR_PROCESSOR') {
    const orgOk = Boolean(user.organizationName && user.organizationName.trim().length > 0);
    const locOk = Boolean(user.facilityLocation && user.facilityLocation.trim().length > 0);
    const licOk = Boolean(user.licenseNumber && user.licenseNumber.trim().length > 0);
    return nameOk && phoneOk && orgOk && locOk && licOk;
  }

  // 3. Lab Testing: Requires authorized person name, contact, lab name, lab address, and accreditation number
  if (role === 'LAB') {
    const orgOk = Boolean(user.organizationName && user.organizationName.trim().length > 0);
    const locOk = Boolean(user.facilityLocation && user.facilityLocation.trim().length > 0);
    const licOk = Boolean(user.licenseNumber && user.licenseNumber.trim().length > 0);
    return nameOk && phoneOk && orgOk && locOk && licOk;
  }

  // 4. Packaging: Requires authorized person name, contact, packaging company name, facility location, and FSSAI license
  if (role === 'PACKAGING') {
    const orgOk = Boolean(user.organizationName && user.organizationName.trim().length > 0);
    const locOk = Boolean(user.facilityLocation && user.facilityLocation.trim().length > 0);
    const licOk = Boolean(user.licenseNumber && user.licenseNumber.trim().length > 0);
    return nameOk && phoneOk && orgOk && locOk && licOk;
  }

  // Admin / other roles
  return nameOk && (emailOk || phoneOk);
}

export const PROFILE_INCOMPLETE_RESPONSE = {
  success: false,
  code: 'PROFILE_INCOMPLETE',
  message: 'Please complete your profile and required verification details before continuing with this request.',
  error: 'Please complete your profile and required verification details before continuing with this request.'
};
