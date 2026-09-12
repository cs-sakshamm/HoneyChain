"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const verificationService_1 = require("./services/verificationService");
const otpService_1 = require("./services/otpService");
function runTests() {
    return __awaiter(this, void 0, void 0, function* () {
        var _a, _b;
        console.log('=== Starting Harvester Verification System Automated Tests ===\n');
        const testHarvesterId = `test-harv-${Date.now()}`;
        let passedTests = 0;
        let failedTests = 0;
        function assert(condition, testName) {
            if (condition) {
                console.log(`✓ PASS: ${testName}`);
                passedTests++;
            }
            else {
                console.error(`✗ FAIL: ${testName}`);
                failedTests++;
            }
        }
        try {
            // 1. Start verification
            console.log('--- 1. Initial State & Start Verification ---');
            const initRecord = yield verificationService_1.verificationService.getOrCreateVerification(testHarvesterId);
            assert(initRecord.verificationStatus === 'Not Started', 'Initial verification status is "Not Started"');
            assert(initRecord.governmentIdVerified === 'Not Started', 'Initial Government ID status is "Not Started"');
            // 2. Negative Test: Blockchain Verify before requirements met
            console.log('\n--- 2. Negative Test: Gating Blockchain Verification ---');
            try {
                yield verificationService_1.verificationService.submitBlockchainVerification(testHarvesterId);
                assert(false, 'Blockchain verification should fail if parameters are incomplete');
            }
            catch (e) {
                assert(e.message.includes('Requirements not met'), 'Blocked blockchain verification before requirements met');
            }
            // 3. Step 1: Government ID Verification
            console.log('\n--- 3. Step 1: Government ID Verification & Masking ---');
            const govResult = yield verificationService_1.verificationService.submitGovernmentId(testHarvesterId, 'NATIONAL_ID', 'ID-987654321');
            assert(govResult.governmentIdVerified === 'Verified', 'Government ID verified');
            assert(((_a = govResult.governmentIdReference) === null || _a === void 0 ? void 0 : _a.startsWith('DOC-NAT-***4321')) === true, 'Government ID properly masked without exposing complete ID');
            assert(govResult.governmentIdDocHash !== undefined && govResult.governmentIdDocHash.length === 64, 'SHA-256 document checksum generated');
            // 4. Step 2: Mobile Number & OTP Verification
            console.log('\n--- 4. Step 2: Mobile OTP System ---');
            const testPhone = `+1555${Date.now().toString().slice(-7)}`;
            const otpSent = yield otpService_1.otpService.sendOtp(testPhone);
            assert(otpSent.success === true, 'OTP generated successfully');
            assert(otpSent.cooldownSeconds === 60, '60-second cooldown returned');
            assert(otpSent.devOtp !== undefined && otpSent.devOtp.length === 6, 'Cryptographically generated 6-digit OTP');
            // Test Cooldown enforcement
            const cooldownTest = yield otpService_1.otpService.sendOtp(testPhone);
            assert(cooldownTest.success === false, 'Rate limiter prevents spam before cooldown expires');
            // Test Wrong OTP
            const wrongOtpResult = yield otpService_1.otpService.verifyOtp(testPhone, '000000');
            assert(wrongOtpResult.success === false, 'Incorrect OTP is rejected');
            // Test Valid OTP
            const validOtpSubmission = yield verificationService_1.verificationService.submitMobileVerification(testHarvesterId, testPhone, otpSent.devOtp);
            assert(validOtpSubmission.mobileVerified === 'Verified', 'Mobile number verified successfully with valid OTP');
            // 5. Step 3: Beekeeper Registration ID
            console.log('\n--- 5. Step 3: Beekeeper Registration ID ---');
            // Test Invalid Format
            try {
                yield verificationService_1.verificationService.submitRegistrationId(testHarvesterId, '??$$');
                assert(false, 'Invalid registration ID format should be rejected');
            }
            catch (e) {
                assert(e.message.includes('Invalid') || e.message.includes('format') || e.message.includes('characters'), 'Invalid registration format rejected');
            }
            // Valid Format
            const regResult = yield verificationService_1.verificationService.submitRegistrationId(testHarvesterId, 'BK-OR-8842', 'STATE_REGISTRY');
            assert(regResult.registrationVerified === 'Verified', 'Beekeeper Registration ID verified');
            assert(regResult.registrationId === 'BK-OR-8842', 'Registration ID stored correctly');
            // 6. Step 4: Apiary Location Verification
            console.log('\n--- 6. Step 4: Apiary Location Verification ---');
            const locResult = yield verificationService_1.verificationService.submitApiaryLocation(testHarvesterId, 'Highland Apiary #1', 'Cascade Valley, OR', '44.0521° N, 121.3153° W');
            assert(locResult.locationVerified === 'Verified', 'Apiary location verified');
            assert(locResult.apiaryLocation === 'Cascade Valley, OR', 'Public generalized region stored');
            assert(locResult.apiaryCoordinates === '44.0521° N, 121.3153° W', 'Private GPS coordinates stored off-chain');
            // 7. Step 5: Final Blockchain Verification Record
            console.log('\n--- 7. Step 5: Final Blockchain Verification ---');
            const bcResult = yield verificationService_1.verificationService.submitBlockchainVerification(testHarvesterId);
            assert(bcResult.verification.verificationStatus === 'Verified', 'Harvester status is "Verified"');
            assert(((_b = bcResult.verification.verificationId) === null || _b === void 0 ? void 0 : _b.startsWith('HV-2026-')) === true, 'Unique Harvester Verification ID issued');
            assert(bcResult.verification.verificationHash !== undefined && bcResult.verification.verificationHash.length === 64, 'SHA-256 canonical record hash generated');
            // 8. Step 8: Public QR Verification & Integrity Check
            console.log('\n--- 8. Public Verification & Cryptographic Integrity Check ---');
            const publicLookup = yield verificationService_1.verificationService.getPublicVerificationByVerificationId(bcResult.verification.verificationId);
            assert(publicLookup.found === true, 'Public lookup successfully found verified record');
            assert(publicLookup.integrityVerified === true, 'Cryptographic hash integrity check passed (canonical hash match)');
            assert(publicLookup.status === 'Verified', 'Status displayed as Verified');
            // Negative Test: Fake / Random ID lookup
            const fakeLookup = yield verificationService_1.verificationService.getPublicVerificationByVerificationId('HV-2026-FAKE9999');
            assert(fakeLookup.found === false, 'Fake / Non-existent verification ID returns "Verification Record Not Found"');
            console.log(`\n========================================`);
            console.log(`TEST SUMMARY: ${passedTests} passed, ${failedTests} failed`);
            console.log(`========================================\n`);
            if (failedTests > 0) {
                process.exit(1);
            }
        }
        catch (error) {
            console.error('Test execution error:', error);
            process.exit(1);
        }
    });
}
runTests();
