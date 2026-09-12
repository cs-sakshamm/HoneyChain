import { PrismaClient } from '@prisma/client';
import * as crypto from 'crypto';
import { blockchainService } from './blockchainService';
import { otpService } from './otpService';

const prisma = new PrismaClient();

export class VerificationService {
  /**
   * Get or initialize HarvesterVerification record
   */
  async getOrCreateVerification(harvesterId: string) {
    if (!harvesterId || harvesterId.trim().length === 0) {
      throw new Error('harvesterId is required');
    }

    const cleanHarvesterId = harvesterId.trim();

    // Check user exists by ID or email
    let user = await prisma.user.findFirst({
      where: {
        OR: [
          { id: cleanHarvesterId },
          { email: cleanHarvesterId.toLowerCase() }
        ]
      }
    });

    if (!user) {
      if (cleanHarvesterId === 'default' || cleanHarvesterId === 'demo') {
        user = await prisma.user.findFirst({ where: { role: 'HARVESTER' } });
      }
      if (!user) {
        const uniqueSuffix = crypto.randomBytes(4).toString('hex');
        user = await prisma.user.create({
          data: {
            id: cleanHarvesterId.length > 5 ? cleanHarvesterId : undefined,
            name: 'Licensed Harvester',
            email: `harvester-${uniqueSuffix}@honeychain.io`,
            role: 'HARVESTER'
          }
        });
      }
    }

    let record = await prisma.harvesterVerification.findUnique({
      where: { harvesterId: user.id },
      include: { harvester: true }
    });

    if (!record) {
      record = await prisma.harvesterVerification.create({
        data: {
          harvesterId: user.id,
          governmentIdVerified: 'Not Started',
          mobileVerified: 'Not Started',
          registrationVerified: 'Not Started',
          locationVerified: 'Not Started',
          verificationStatus: 'Not Started'
        },
        include: { harvester: true }
      });
    }

    return record;
  }

  /**
   * 1. Submit Government ID for verification
   * Preserves privacy: Stores only masked reference (DOC-***XXXX) and SHA-256 document checksum.
   * Never stores raw document numbers in plaintext.
   */
  async submitGovernmentId(
    harvesterId: string,
    docTypeRaw: string,
    docNumberRaw: string
  ) {
    const validDocTypes = ['NATIONAL_ID', 'PASSPORT', 'DRIVERS_LICENSE', 'BEEKEEPER_PERMIT', 'APICULTURE_PERMIT'];
    const docType = (docTypeRaw || 'NATIONAL_ID').toUpperCase().trim();
    const docNumber = (docNumberRaw || '').trim();

    if (!validDocTypes.includes(docType)) {
      throw new Error(`Invalid document type "${docType}". Supported types: National ID, Passport, Driver's License, Apiculture Permit.`);
    }

    if (!docNumber || docNumber.length < 5) {
      throw new Error('Please provide a valid Government ID / Document number (minimum 5 characters).');
    }

    // Mask ID: keep prefix + last 4 characters, mask middle
    const last4 = docNumber.slice(-4).toUpperCase();
    const prefix = docType.substring(0, 3);
    const maskedRef = `DOC-${prefix}-***${last4}`;
    
    // Compute deterministic SHA-256 tamper-evident checksum of canonical raw document number
    const canonicalDocNumber = docNumber.replace(/\s+/g, '').toUpperCase();
    const docHash = crypto.createHash('sha256').update(canonicalDocNumber).digest('hex');

    const existing = await this.getOrCreateVerification(harvesterId);

    // Update record
    const updated = await prisma.harvesterVerification.update({
      where: { id: existing.id },
      data: {
        governmentIdType: docType,
        governmentIdReference: maskedRef,
        governmentIdDocHash: docHash,
        governmentIdVerified: 'Verified',
        governmentIdSubmittedAt: new Date(),
        verificationStatus: existing.verificationStatus === 'Not Started' ? 'In Progress' : existing.verificationStatus
      },
      include: { harvester: true }
    });

    return updated;
  }

  /**
   * 2. Submit Mobile OTP Verification
   */
  async submitMobileVerification(
    harvesterId: string,
    mobileRaw: string,
    otp: string
  ) {
    const verification = await this.getOrCreateVerification(harvesterId);
    const mobile = otpService.sanitizeMobile(mobileRaw);

    const otpResult = await otpService.verifyOtp(mobile, otp);
    if (!otpResult.success) {
      throw new Error(otpResult.message);
    }

    // Mark mobile as verified in verification record
    const updated = await prisma.harvesterVerification.update({
      where: { id: verification.id },
      data: {
        mobileNumber: mobile,
        mobileVerified: 'Verified',
        mobileVerifiedAt: new Date(),
        verificationStatus: verification.verificationStatus === 'Not Started' ? 'In Progress' : verification.verificationStatus
      },
      include: { harvester: true }
    });

    return updated;
  }

  /**
   * 3. Submit Beekeeper Registration ID
   */
  async submitRegistrationId(
    harvesterId: string,
    registrationIdRaw: string,
    registrationTypeRaw?: string
  ) {
    const regId = (registrationIdRaw || '').trim().toUpperCase();
    const regType = (registrationTypeRaw || 'STATE_REGISTRY').toUpperCase().trim();
    const validRegTypes = ['STATE_REGISTRY', 'COOPERATIVE', 'APICULTURE_BOARD', 'NATIONAL_REGISTRY'];

    if (!validRegTypes.includes(regType)) {
      throw new Error(`Invalid registration type. Supported types: ${validRegTypes.join(', ')}.`);
    }

    if (!regId || regId.length < 5) {
      throw new Error('Registration ID must be at least 5 alphanumeric characters.');
    }

    // Format validation: Alphanumeric and dashes (e.g. BK-OR-8842, BEE-2026-991, COOP-USA-41)
    const validFormat = /^[A-Z0-9-]{5,24}$/.test(regId);
    if (!validFormat) {
      throw new Error('Invalid Beekeeper Registration ID format. Use format like BK-OR-8842 or COOP-4921 (5-24 alphanumeric and dashes).');
    }

    const verification = await this.getOrCreateVerification(harvesterId);

    const updated = await prisma.harvesterVerification.update({
      where: { id: verification.id },
      data: {
        registrationId: regId,
        registrationType: regType,
        registrationVerified: 'Verified',
        registrationSubmittedAt: new Date(),
        verificationStatus: verification.verificationStatus === 'Not Started' ? 'In Progress' : verification.verificationStatus
      },
      include: { harvester: true }
    });

    return updated;
  }

  /**
   * Helper to validate GPS coordinate values
   */
  public parseAndValidateCoordinates(coordinatesRaw: string): { isValid: boolean; error?: string } {
    if (!coordinatesRaw || coordinatesRaw.trim().length === 0) {
      return { isValid: true };
    }

    const raw = coordinatesRaw.trim();
    // Pattern 1: standard "lat, lng" e.g. "44.0521, -121.3153"
    const standardMatch = raw.match(/^(-?\d+(\.\d+)?)\s*,\s*(-?\d+(\.\d+)?)$/);
    if (standardMatch) {
      const lat = parseFloat(standardMatch[1]);
      const lng = parseFloat(standardMatch[3]);
      if (lat < -90 || lat > 90) {
        return { isValid: false, error: 'Latitude must be between -90 and +90 degrees.' };
      }
      if (lng < -180 || lng > 180) {
        return { isValid: false, error: 'Longitude must be between -180 and +180 degrees.' };
      }
      return { isValid: true };
    }

    // Pattern 2: directional "44.0521° N, 121.3153° W"
    const directionalMatch = raw.match(/^(\d+(\.\d+)?)\s*°?\s*([NSns])\s*,\s*(\d+(\.\d+)?)\s*°?\s*([EWew])$/);
    if (directionalMatch) {
      const latVal = parseFloat(directionalMatch[1]);
      const lngVal = parseFloat(directionalMatch[4]);
      if (latVal < 0 || latVal > 90) {
        return { isValid: false, error: 'Latitude must be between 0 and 90 degrees.' };
      }
      if (lngVal < 0 || lngVal > 180) {
        return { isValid: false, error: 'Longitude must be between 0 and 180 degrees.' };
      }
      return { isValid: true };
    }

    // If it's a non-empty string that contains numbers, check general bounds
    const numbers = raw.match(/-?\d+(\.\d+)?/g);
    if (numbers && numbers.length >= 2) {
      const lat = parseFloat(numbers[0]);
      const lng = parseFloat(numbers[1]);
      if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        return { isValid: true };
      }
    }

    return { isValid: false, error: 'Invalid coordinate format. Use decimal format (e.g. "44.0521, -121.3153") or directional format (e.g. "44.0521° N, 121.3153° W").' };
  }

  /**
   * 4. Submit Apiary Location Verification
   * Stores public generalized region vs private exact coordinates off-chain
   */
  async submitApiaryLocation(
    harvesterId: string,
    apiaryNameRaw: string,
    apiaryLocationRaw: string,
    apiaryCoordinatesRaw?: string
  ) {
    const apiaryName = (apiaryNameRaw || '').trim();
    const apiaryLocation = (apiaryLocationRaw || '').trim();
    const apiaryCoordinates = (apiaryCoordinatesRaw || '').trim();

    if (!apiaryLocation || apiaryLocation.length < 3) {
      throw new Error('Please specify a valid Apiary Region / Location (minimum 3 characters).');
    }

    if (apiaryCoordinates) {
      const coordValidation = this.parseAndValidateCoordinates(apiaryCoordinates);
      if (!coordValidation.isValid) {
        throw new Error(coordValidation.error || 'Invalid GPS coordinates.');
      }
    }

    const verification = await this.getOrCreateVerification(harvesterId);

    const updated = await prisma.harvesterVerification.update({
      where: { id: verification.id },
      data: {
        apiaryName: apiaryName || 'Primary Apiary',
        apiaryLocation: apiaryLocation, // Generalized region for public view
        apiaryCoordinates: apiaryCoordinates || null, // Private GPS off-chain
        locationVerified: 'Verified',
        locationSubmittedAt: new Date(),
        verificationStatus: verification.verificationStatus === 'Not Started' ? 'In Progress' : verification.verificationStatus
      },
      include: { harvester: true }
    });

    return updated;
  }

  /**
   * 5. Submit Final Blockchain Verification
   * Gated: Only proceeds when all 4 parameters are verified.
   * Generates unique Verification ID (HV-2026-XXXX) and publishes SHA-256 record hash on-chain.
   * Idempotent: If already verified, returns existing record.
   */
  async submitBlockchainVerification(harvesterId: string) {
    const record = await this.getOrCreateVerification(harvesterId);

    // Idempotency: Return existing state if already verified on-chain
    if (record.verificationStatus === 'Verified' && record.verificationId && record.verificationHash) {
      return {
        verification: record,
        blockchain: {
          success: true,
          txHash: record.transactionHash || undefined,
          blockNumber: record.blockNumber || undefined,
          network: record.blockchainNetwork || blockchainService.networkName
        },
        canonicalPayload: {
          verificationId: record.verificationId,
          harvesterId: record.harvesterId,
          harvesterName: record.harvester?.name || 'Harvester',
          governmentIdReference: record.governmentIdReference,
          governmentIdDocHash: record.governmentIdDocHash,
          mobileVerified: record.mobileVerified,
          registrationId: record.registrationId,
          registrationType: record.registrationType,
          apiaryName: record.apiaryName,
          apiaryLocation: record.apiaryLocation,
          verifiedAt: record.verifiedAt?.toISOString()
        }
      };
    }

    // Strict 4/4 Verification Gate: Verify all 4 parameters are satisfied
    const issues: string[] = [];
    if (record.governmentIdVerified !== 'Verified') {
      issues.push('Government ID is not verified');
    }
    if (record.mobileVerified !== 'Verified') {
      issues.push('Mobile OTP is not verified');
    }
    if (record.registrationVerified !== 'Verified') {
      issues.push('Beekeeper Registration ID is not verified');
    }
    if (record.locationVerified !== 'Verified') {
      issues.push('Apiary Location is not verified');
    }

    if (issues.length > 0) {
      throw new Error(`Cannot complete blockchain verification. Requirements not met: ${issues.join(', ')}`);
    }

    // Generate unique collision-free Harvester Verification ID
    let verificationId = record.verificationId;
    if (!verificationId) {
      let isUnique = false;
      while (!isUnique) {
        const candidateId = `HV-2026-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
        const existingWithId = await prisma.harvesterVerification.findUnique({ where: { verificationId: candidateId } });
        if (!existingWithId) {
          verificationId = candidateId;
          isUnique = true;
        }
      }
    }

    const verifiedAt = new Date();

    // Construct canonical verification payload containing ONLY approved public non-sensitive fields
    const canonicalPayload = {
      verificationId,
      harvesterId: record.harvesterId,
      harvesterName: record.harvester?.name || 'Harvester',
      governmentIdReference: record.governmentIdReference,
      governmentIdDocHash: record.governmentIdDocHash,
      mobileVerified: record.mobileVerified,
      registrationId: record.registrationId,
      registrationType: record.registrationType,
      apiaryName: record.apiaryName,
      apiaryLocation: record.apiaryLocation,
      verifiedAt: verifiedAt.toISOString()
    };

    // Compute cryptographic SHA-256 Record Hash
    const recordHash = blockchainService.computeVerificationHash(canonicalPayload);

    // Call smart contract to record on-chain
    const blockchainResult = await blockchainService.recordHarvesterVerificationOnChain(
      verificationId!,
      record.harvesterId,
      recordHash,
      'VERIFIED'
    );

    // Persist to database
    const updated = await prisma.harvesterVerification.update({
      where: { id: record.id },
      data: {
        verificationId,
        verificationHash: recordHash,
        blockchainNetwork: blockchainResult.network,
        transactionHash: blockchainResult.txHash || null,
        blockNumber: blockchainResult.blockNumber || null,
        verificationStatus: 'Verified',
        verifiedAt: verifiedAt
      },
      include: { harvester: true }
    });

    return {
      verification: updated,
      blockchain: blockchainResult,
      canonicalPayload
    };
  }

  /**
   * Public Verification Check (Used by QR code scanners and public certificate viewers)
   * Validates cryptographic record hash integrity
   * Returns ONLY safe sanitized public details (Never raw IDs, OTPs, or private GPS coordinates)
   */
  async getPublicVerificationByVerificationId(verificationId: string) {
    const cleanId = (verificationId || '').trim().toUpperCase();

    const record = await prisma.harvesterVerification.findUnique({
      where: { verificationId: cleanId },
      include: { harvester: true }
    });

    if (!record || record.verificationStatus !== 'Verified') {
      return {
        found: false,
        message: 'Verification Record Not Found. This ID is either invalid, revoked, or not yet verified.'
      };
    }

    // Verify hash integrity against canonical record
    const canonicalPayload = {
      verificationId: record.verificationId,
      harvesterId: record.harvesterId,
      harvesterName: record.harvester?.name || 'Harvester',
      governmentIdReference: record.governmentIdReference,
      governmentIdDocHash: record.governmentIdDocHash,
      mobileVerified: record.mobileVerified,
      registrationId: record.registrationId,
      registrationType: record.registrationType,
      apiaryName: record.apiaryName,
      apiaryLocation: record.apiaryLocation,
      verifiedAt: record.verifiedAt?.toISOString()
    };

    const computedHash = blockchainService.computeVerificationHash(canonicalPayload);
    const isIntegrityValid = computedHash === record.verificationHash;

    // Query on-chain record status
    const onChainResult = await blockchainService.getHarvesterVerificationOnChain(cleanId);

    return {
      found: true,
      verificationId: record.verificationId,
      status: 'Verified',
      harvesterName: record.harvester?.name || 'Verified Harvester',
      verifiedAt: record.verifiedAt,
      blockchainNetwork: record.blockchainNetwork || 'HoneyChain Provenance Ledger',
      transactionHash: record.transactionHash,
      blockNumber: record.blockNumber,
      recordHash: record.verificationHash,
      integrityVerified: isIntegrityValid,
      onChainConfirmed: onChainResult.found,
      publicDetails: {
        governmentIdStatus: record.governmentIdVerified,
        governmentIdReference: record.governmentIdReference,
        mobileStatus: record.mobileVerified,
        registrationId: record.registrationId,
        registrationType: record.registrationType,
        apiaryLocation: record.apiaryLocation,
        apiaryName: record.apiaryName
      },
      verificationUrl: `https://honeychain.io/verify/harvester/${record.verificationId}`
    };
  }

  /**
   * Admin / Verifier Review of Harvester Verification
   */
  async reviewVerification(
    harvesterId: string,
    field: 'governmentId' | 'registration' | 'all',
    decision: 'Verified' | 'Rejected',
    notes?: string
  ) {
    const existing = await this.getOrCreateVerification(harvesterId);
    const dataToUpdate: any = { reviewNotes: notes || null };

    if (field === 'governmentId' || field === 'all') {
      dataToUpdate.governmentIdVerified = decision;
    }
    if (field === 'registration' || field === 'all') {
      dataToUpdate.registrationVerified = decision;
    }
    if (decision === 'Rejected') {
      dataToUpdate.verificationStatus = 'Rejected';
    }

    const updated = await prisma.harvesterVerification.update({
      where: { id: existing.id },
      data: dataToUpdate,
      include: { harvester: true }
    });

    return updated;
  }
}


export const verificationService = new VerificationService();
