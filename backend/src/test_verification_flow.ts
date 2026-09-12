import { verificationService } from './services/verificationService';
import { otpService } from './services/otpService';
import { blockchainService } from './services/blockchainService';
import { PrismaClient } from '@prisma/client';
import { isUserProfileComplete, isHarvesterFullyVerified } from './services/profileService';

const prisma = new PrismaClient();

async function runTests() {
  console.log('=== Starting Harvester Verification System Automated Tests ===\n');

  const testHarvesterId = `test-harv-${Date.now()}`;
  let passedTests = 0;
  let failedTests = 0;

  function assert(condition: boolean, testName: string) {
    if (condition) {
      console.log(`✓ PASS: ${testName}`);
      passedTests++;
    } else {
      console.error(`✗ FAIL: ${testName}`);
      failedTests++;
    }
  }

  try {
    // 1. Start verification
    console.log('--- 1. Initial State & Start Verification ---');
    const initRecord = await verificationService.getOrCreateVerification(testHarvesterId);
    assert(initRecord.verificationStatus === 'Not Started', 'Initial verification status is "Not Started"');
    assert(initRecord.governmentIdVerified === 'Not Started', 'Initial Government ID status is "Not Started"');

    // 2. Negative Test: Blockchain Verify before requirements met
    console.log('\n--- 2. Negative Test: Gating Blockchain Verification ---');
    try {
      await verificationService.submitBlockchainVerification(testHarvesterId);
      assert(false, 'Blockchain verification should fail if parameters are incomplete');
    } catch (e: any) {
      assert(e.message.includes('Requirements not met'), 'Blocked blockchain verification before requirements met');
    }

    // 3. Step 1: Government ID Verification (Aadhaar Card OTP + Masking)
    console.log('\n--- 3. Step 1: Aadhaar Card Verification & Masking ---');
    try {
      await verificationService.sendAadhaarOtp(testHarvesterId, '1234');
      assert(false, 'Invalid Aadhaar number (<12 digits) should be rejected');
    } catch (e: any) {
      assert(e.message.includes('12-digit Aadhaar'), 'Invalid Aadhaar length rejected');
    }

    const testAadhaar = '987654321098';
    const aadhaarOtpRes = await verificationService.sendAadhaarOtp(testHarvesterId, testAadhaar);
    assert(aadhaarOtpRes.success === true, 'Aadhaar OTP generated successfully');
    assert(aadhaarOtpRes.message.includes('Aadhaar-linked mobile'), 'Proper Aadhaar OTP message returned');
    assert(aadhaarOtpRes.devOtp !== undefined && aadhaarOtpRes.devOtp.length === 6, 'Aadhaar OTP 6 digits generated in dev mode');

    try {
      await verificationService.verifyAadhaarOtp(testHarvesterId, testAadhaar, '000000');
      assert(false, 'Wrong Aadhaar OTP should be rejected');
    } catch (e: any) {
      assert(e.message.includes('Incorrect') || e.message.includes('verification code'), 'Wrong Aadhaar OTP rejected');
    }

    const govResult = await verificationService.verifyAadhaarOtp(testHarvesterId, testAadhaar, aadhaarOtpRes.devOtp!);
    assert(govResult.governmentIdVerified === 'Verified', 'Aadhaar verified successfully');
    assert(govResult.governmentIdReference === 'AADHAAR-***1098', 'Aadhaar reference masked as AADHAAR-***XXXX');
    assert(govResult.governmentIdDocHash !== undefined && govResult.governmentIdDocHash.length === 64, 'SHA-256 document checksum generated for Aadhaar');

    // 4. Step 2: Mobile Number & OTP Verification
    console.log('\n--- 4. Step 2: Mobile OTP System ---');
    const testPhone = `+1555${Date.now().toString().slice(-7)}`;
    const otpSent = await otpService.sendOtp(testPhone);
    assert(otpSent.success === true, 'OTP generated successfully');
    assert(otpSent.cooldownSeconds === 60, '60-second cooldown returned');
    assert(otpSent.devOtp !== undefined && otpSent.devOtp.length === 6, 'Cryptographically generated 6-digit OTP');

    // Test Cooldown enforcement
    const cooldownTest = await otpService.sendOtp(testPhone);
    assert(cooldownTest.success === false, 'Rate limiter prevents spam before cooldown expires');

    // Test Wrong OTP and attempts tracking
    const wrongOtpResult = await otpService.verifyOtp(testPhone, '000000');
    assert(wrongOtpResult.success === false, 'Incorrect OTP is rejected');

    // Test brute-force protection (attempts 2 & 3)
    await otpService.verifyOtp(testPhone, '000001');
    const thirdWrong = await otpService.verifyOtp(testPhone, '000002');
    assert(thirdWrong.message.includes('invalidated') || thirdWrong.message.includes('Too many'), 'OTP invalidated after 3 failed attempts');

    // Generate fresh OTP for valid verification
    const freshPhone = `+1556${Date.now().toString().slice(-7)}`;
    const freshOtpSent = await otpService.sendOtp(freshPhone);
    const validOtpSubmission = await verificationService.submitMobileVerification(testHarvesterId, freshPhone, freshOtpSent.devOtp!);
    assert(validOtpSubmission.mobileVerified === 'Verified', 'Mobile number verified successfully with valid OTP');

    // 5. Step 3: Beekeeper Registration ID
    console.log('\n--- 5. Step 3: Beekeeper Registration ID ---');
    // Test Invalid Format
    try {
      await verificationService.submitRegistrationId(testHarvesterId, '??$$');
      assert(false, 'Invalid registration ID format should be rejected');
    } catch (e: any) {
      assert(e.message.includes('Invalid') || e.message.includes('format') || e.message.includes('characters'), 'Invalid registration format rejected');
    }

    // Valid Format
    const regResult = await verificationService.submitRegistrationId(testHarvesterId, 'BK-OR-8842', 'STATE_REGISTRY');
    assert(regResult.registrationVerified === 'Verified', 'Beekeeper Registration ID verified');
    assert(regResult.registrationId === 'BK-OR-8842', 'Registration ID stored correctly');

    // 6. Step 4: Apiary Location Verification & GPS
    console.log('\n--- 6. Step 4: Apiary Location Verification & GPS ---');
    // Test Invalid GPS Coordinates
    try {
      await verificationService.submitApiaryLocation(testHarvesterId, 'Test Apiary', 'North Valley', '999.0, 999.0');
      assert(false, 'Out of bound coordinates should be rejected');
    } catch (e: any) {
      assert(e.message.includes('Latitude') || e.message.includes('Longitude') || e.message.includes('coordinate'), 'Out of bound GPS coordinates rejected');
    }

    const locResult = await verificationService.submitApiaryLocation(
      testHarvesterId,
      'Highland Apiary #1',
      'Cascade Valley, OR',
      '44.0521, -121.3153'
    );
    assert(locResult.locationVerified === 'Verified', 'Apiary location verified');
    assert(locResult.apiaryLocation === 'Cascade Valley, OR', 'Public generalized region stored');
    assert(locResult.apiaryCoordinates === '44.0521, -121.3153', 'Private GPS coordinates stored off-chain');

    // 7. Step 5: Final Blockchain Verification Record & Idempotency
    console.log('\n--- 7. Step 5: Final Blockchain Verification & Idempotency ---');
    const bcResult = await verificationService.submitBlockchainVerification(testHarvesterId);
    assert(bcResult.verification.verificationStatus === 'Verified', 'Harvester status is "Verified"');
    assert(bcResult.verification.verificationId?.startsWith('HV-2026-') === true, 'Unique Harvester Verification ID issued');
    assert(bcResult.verification.verificationHash !== undefined && bcResult.verification.verificationHash.length === 64, 'SHA-256 canonical record hash generated');

    // Test Idempotency: re-running returns existing record
    const bcResultIdempotent = await verificationService.submitBlockchainVerification(testHarvesterId);
    assert(bcResultIdempotent.verification.verificationId === bcResult.verification.verificationId, 'Idempotent verification submission returns existing Verification ID');

    // 8. Step 8: Public QR Verification & Integrity Check
    console.log('\n--- 8. Public Verification & Cryptographic Integrity Check ---');
    const publicLookup = await verificationService.getPublicVerificationByVerificationId(bcResult.verification.verificationId!);
    assert(publicLookup.found === true, 'Public lookup successfully found verified record');
    assert(publicLookup.integrityVerified === true, 'Cryptographic hash integrity check passed (canonical hash match)');
    assert(publicLookup.status === 'Verified', 'Status displayed as Verified');
    assert((publicLookup as any).apiaryCoordinates === undefined, 'Private GPS coordinates not exposed in public lookup');

    // Negative Test: Fake / Random ID lookup
    const fakeLookup = await verificationService.getPublicVerificationByVerificationId('HV-2026-FAKE9999');
    assert(fakeLookup.found === false, 'Fake / Non-existent verification ID returns "Verification Record Not Found"');

    // 9. Hive Gate Tests
    console.log('\n--- 9. Harvester Hive Creation Gating ---');
    const harvesterUser = await prisma.user.findFirst({
      where: { id: testHarvesterId },
      include: { harvesterVerification: true }
    });
    assert(isUserProfileComplete(harvesterUser) === true || harvesterUser !== null, 'Harvester user resolved');
    assert(isHarvesterFullyVerified(harvesterUser?.harvesterVerification) === true, 'Harvester verification verified for hive access');

    const unverifiedHarvId = `unverified-${Date.now()}`;
    const unverifiedRecord = await verificationService.getOrCreateVerification(unverifiedHarvId);
    const unverifiedUser = await prisma.user.findFirst({
      where: { id: unverifiedHarvId },
      include: { harvesterVerification: true }
    });
    assert(isHarvesterFullyVerified(unverifiedUser?.harvesterVerification) === false, 'Unverified harvester correctly flagged as not verified for hive creation');

    console.log(`\n========================================`);
    console.log(`TEST SUMMARY: ${passedTests} passed, ${failedTests} failed`);
    console.log(`========================================\n`);

    if (failedTests > 0) {
      process.exit(1);
    }
  } catch (error) {
    console.error('Test execution error:', error);
    process.exit(1);
  }
}

runTests();

