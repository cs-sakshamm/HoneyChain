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
    // Check user exists or create placeholder user if needed
    let user = await prisma.user.findUnique({ where: { id: harvesterId } });
    if (!user) {
      // Check by fallback / demo user
      user = await prisma.user.findFirst({ where: { role: 'HARVESTER' } });
      if (!user) {
        user = await prisma.user.create({
          data: {
            id: harvesterId,
            name: 'Licensed Harvester',
            email: `harvester-${harvesterId.slice(0, 8)}@honeychain.io`,
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
   */
  async submitGovernmentId(
    harvesterId: string,
    docTypeRaw: string,
    docNumberRaw: string
  ) {
    const docType = (docTypeRaw || 'NATIONAL_ID').toUpperCase().trim();
    const docNumber = (docNumberRaw || '').trim();

    if (!docNumber || docNumber.length < 5) {
      throw new Error('Please provide a valid Government ID / Document number (minimum 5 characters).');
    }

    // Mask ID: keep prefix + last 4 characters, mask middle
    const last4 = docNumber.slice(-4).toUpperCase();
    const maskedRef = `DOC-${docType.substring(0, 3)}-***${last4}`;
    
    // Compute SHA-256 tamper-evident checksum of raw document number
    const docHash = crypto.createHash('sha256').update(docNumber).digest('hex');

    const existing = await this.getOrCreateVerification(harvesterId);

    // Update record
    const updated = await prisma.harvesterVerification.update({
      where: { id: existing.id },
      data: {
        governmentIdType: docType,
        governmentIdReference: maskedRef,
        governmentIdDocHash: docHash,
        governmentIdVerified: 'Verified', // Verified once valid structural format & hash recorded
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

    if (!regId || regId.length < 5) {
      throw new Error('Registration ID must be at least 5 alphanumeric characters.');
    }

    // Format validation: Alphanumeric and dashes (e.g. BK-OR-8842, BEE-2026-991, COOP-USA-41)
    const validFormat = /^[A-Z0-9-]{5,24}$/.test(regId);
    if (!validFormat) {
      throw new Error('Invalid Beekeeper Registration ID format. Use format like BK-OR-8842 or COOP-4921.');
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
      throw new Error('Please specify a valid Apiary Region / Location.');
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
   */
  async submitBlockchainVerification(harvesterId: string) {
    const record = await this.getOrCreateVerification(harvesterId);

    // Verify all 4 parameters are satisfied
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

    // Generate unique Harvester Verification ID if not already assigned
    const verificationId = record.verificationId || `HV-2026-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    const verifiedAt = new Date();

    // Construct canonical verification payload (Off-Chain Data)
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
      verificationId,
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

    // Optional on-chain check
    const onChainResult = await blockchainService.getHarvesterVerificationOnChain(cleanId);

    return {
      found: true,
      verificationId: record.verificationId,
      status: 'Verified',
      harvesterName: record.harvester?.name || 'Verified Harvester',
      verifiedAt: record.verifiedAt,
      blockchainNetwork: record.blockchainNetwork || 'HoneyChain Ledger',
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
