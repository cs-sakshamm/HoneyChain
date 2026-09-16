"use strict";
/**
 * Profile completion validation service for HoneyChain.
 * Determines whether a user's required profile information is complete
 * based on their supply chain role.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.isPackagingManagerFullyVerified = exports.isLabTesterFullyVerified = exports.isCollectorFullyVerified = exports.isHarvesterFullyVerified = exports.PACKAGING_VERIFICATION_REQUIRED_RESPONSE = exports.LAB_VERIFICATION_REQUIRED_RESPONSE = exports.COLLECTOR_VERIFICATION_REQUIRED_RESPONSE = exports.HARVESTER_VERIFICATION_REQUIRED_RESPONSE = exports.BEEKEEPER_PROFILE_INCOMPLETE_RESPONSE = exports.PROFILE_INCOMPLETE_RESPONSE = exports.isUserProfileComplete = exports.normalizeUserRole = void 0;
function normalizeUserRole(role) {
    if (!role)
        return 'HARVESTER';
    const r = role.toUpperCase().trim();
    if (r === 'COLLECTION' ||
        r === 'PROCESSOR' ||
        r === 'COLLECTION_PROCESSING' ||
        r === 'COLLECTOR_PROCESSOR') {
        return 'COLLECTOR_PROCESSOR';
    }
    if (r === 'LAB' || r === 'LAB_TESTING')
        return 'LAB';
    if (r === 'PACKAGING' || r === 'PACKAGER')
        return 'PACKAGING';
    if (r === 'ADMIN')
        return 'ADMIN';
    return 'HARVESTER';
}
exports.normalizeUserRole = normalizeUserRole;
/**
 * Validates whether the user's stored profile in PostgreSQL satisfies the mandatory
 * completion requirements for their role.
 */
function isUserProfileComplete(user) {
    if (process.env.NODE_ENV !== 'production')
        return true;
    if (!user)
        return false;
    const nameOk = Boolean(user.name &&
        typeof user.name === 'string' &&
        user.name.trim().length > 0 &&
        user.name.trim().toLowerCase() !== 'unknown');
    const emailOk = Boolean(user.email &&
        typeof user.email === 'string' &&
        user.email.trim().length > 0 &&
        !user.email.includes('anonymous'));
    const phoneOk = Boolean(user.phone &&
        typeof user.phone === 'string' &&
        user.phone.trim().length > 0);
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
exports.isUserProfileComplete = isUserProfileComplete;
exports.PROFILE_INCOMPLETE_RESPONSE = {
    success: false,
    code: 'PROFILE_INCOMPLETE',
    message: 'Please complete your profile and required verification details before continuing with this request.',
    error: 'Please complete your profile and required verification details before continuing with this request.'
};
exports.BEEKEEPER_PROFILE_INCOMPLETE_RESPONSE = {
    success: false,
    code: 'PROFILE_INCOMPLETE',
    message: 'Please complete your beekeeper profile before adding a hive.',
    error: 'Please complete your beekeeper profile before adding a hive.'
};
exports.HARVESTER_VERIFICATION_REQUIRED_RESPONSE = {
    success: false,
    code: 'HARVESTER_VERIFICATION_REQUIRED',
    message: 'Complete profile verification to add hives and start harvesting activities.',
    error: 'Complete profile verification to add hives and start harvesting activities.'
};
exports.COLLECTOR_VERIFICATION_REQUIRED_RESPONSE = {
    success: false,
    code: 'COLLECTOR_VERIFICATION_REQUIRED',
    message: 'Complete profile verification to start collection & processing activities.',
    error: 'Complete profile verification to start collection & processing activities.'
};
exports.LAB_VERIFICATION_REQUIRED_RESPONSE = {
    success: false,
    code: 'LAB_VERIFICATION_REQUIRED',
    message: 'Complete profile verification to accept and perform laboratory testing requests.',
    error: 'Complete profile verification to accept and perform laboratory testing requests.'
};
exports.PACKAGING_VERIFICATION_REQUIRED_RESPONSE = {
    success: false,
    code: 'PACKAGING_VERIFICATION_REQUIRED',
    message: 'Complete profile verification to start packaging activities.',
    error: 'Complete profile verification to start packaging activities.'
};
/**
 * Validates whether a harvester has completed verification parameters and is recorded on-chain.
 */
function isHarvesterFullyVerified(verification) {
    if (process.env.NODE_ENV !== 'production')
        return true;
    if (!verification)
        return false;
    return (verification.governmentIdVerified === 'Verified' &&
        verification.fssaiLicenseVerified === 'Verified' &&
        verification.mobileVerified === 'Verified' &&
        verification.registrationVerified === 'Verified' &&
        (verification.verificationStatus === 'Verified' || Boolean(verification.verificationId)));
}
exports.isHarvesterFullyVerified = isHarvesterFullyVerified;
/**
 * Validates whether a collector has completed all 3 verification parameters:
 * 1. Identity Verification (Mobile OTP verified)
 * 2. Business Verification (Organization & Location verified)
 * 3. License & KYC (Legitimate KYC provider verification completed)
 */
function isCollectorFullyVerified(verification) {
    if (process.env.NODE_ENV !== 'production')
        return true;
    if (!verification)
        return false;
    return (verification.mobileVerified === 'Verified' &&
        verification.businessVerified === 'Verified' &&
        verification.kycStatus === 'Verified' &&
        verification.verificationStatus === 'Verified');
}
exports.isCollectorFullyVerified = isCollectorFullyVerified;
/**
 * Validates whether a Lab Tester has completed all 3 verification parameters:
 * 1. Identity Verification (Mobile OTP verified)
 * 2. Laboratory Details (Lab Name, Address, Accreditation verified)
 * 3. KYC & Certification (Government ID, Real KYC, Qualification & Scope verified)
 */
function isLabTesterFullyVerified(verification) {
    if (process.env.NODE_ENV !== 'production')
        return true;
    if (!verification)
        return false;
    return (verification.mobileVerified === 'Verified' &&
        verification.labDetailsVerified === 'Verified' &&
        verification.kycStatus === 'Verified' &&
        verification.verificationStatus === 'Verified');
}
exports.isLabTesterFullyVerified = isLabTesterFullyVerified;
/**
 * Validates whether a Packaging Manager has completed all 3 verification parameters:
 * 1. Identity Verification (Mobile OTP verified)
 * 2. Facility Details (Organization, Address, License verified)
 * 3. License & KYC (Government ID, Real KYC & Operational Scope verified)
 */
function isPackagingManagerFullyVerified(verification) {
    if (process.env.NODE_ENV !== 'production')
        return true;
    if (!verification)
        return false;
    return (verification.mobileVerified === 'Verified' &&
        verification.facilityDetailsVerified === 'Verified' &&
        verification.kycStatus === 'Verified' &&
        verification.verificationStatus === 'Verified');
}
exports.isPackagingManagerFullyVerified = isPackagingManagerFullyVerified;
