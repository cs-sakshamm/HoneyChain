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
const kyc_1 = require("./services/kyc");
const verificationService_1 = require("./services/verificationService");
const client_1 = require("@prisma/client");
const prisma = new client_1.PrismaClient();
function runKycTests() {
    return __awaiter(this, void 0, void 0, function* () {
        console.log('=== Starting Aadhaar KYC Provider System Automated Tests ===\n');
        let passed = 0;
        let failed = 0;
        function assert(condition, testName) {
            if (condition) {
                console.log(`✓ PASS: ${testName}`);
                passed++;
            }
            else {
                console.error(`✗ FAIL: ${testName}`);
                failed++;
            }
        }
        try {
            // 1. Provider Factory Default
            console.log('--- 1. Provider Factory & Default Sandbox ---');
            kyc_1.KycProviderFactory.resetProvider();
            delete process.env.AADHAAR_PROVIDER;
            const defaultProvider = kyc_1.KycProviderFactory.getProvider();
            assert(defaultProvider instanceof kyc_1.SandboxAadhaarProvider, 'Default provider is SandboxAadhaarProvider');
            assert(defaultProvider.isConfigured === true, 'Sandbox provider is always configured for dev/test');
            assert(defaultProvider.isSandbox === true, 'Sandbox provider is flagged as isSandbox');
            // 2. Sandbox Provider Validation & OTP Flow
            console.log('\n--- 2. Sandbox Aadhaar OTP Initiation & Validation ---');
            const testAadhaar = '548291043821';
            const testHarvesterId = `test-kyc-harv-${Date.now()}`;
            // Negative: Invalid Aadhaar number (<12 digits)
            try {
                yield defaultProvider.initiateAadhaarOtp({ harvesterId: testHarvesterId, aadhaarNumber: '12345' });
                assert(false, 'Should reject invalid Aadhaar length');
            }
            catch (e) {
                assert(e.message.includes('12-digit Aadhaar'), 'Rejects invalid Aadhaar length (<12 digits)');
            }
            // Success: Initiate OTP
            const initRes = yield defaultProvider.initiateAadhaarOtp({ harvesterId: testHarvesterId, aadhaarNumber: testAadhaar });
            assert(initRes.success === true, 'Aadhaar OTP initiation succeeded');
            assert(initRes.transactionId.startsWith('TXN-UIDAI-SBX-'), 'Unique UIDAI transaction ID generated');
            assert(initRes.message.includes('Aadhaar-linked mobile'), 'User-facing message indicates OTP sent to linked mobile');
            assert(initRes.cooldownSeconds === 60, '60-second cooldown returned');
            assert(initRes.devOtp !== undefined && initRes.devOtp.length === 6, '6-digit challenge OTP generated');
            // Rate limiting: Immediate second OTP request before cooldown
            const rateLimitRes = yield defaultProvider.initiateAadhaarOtp({ harvesterId: testHarvesterId, aadhaarNumber: testAadhaar });
            assert(rateLimitRes.success === false, 'Rate limiter prevents duplicate OTP requests during cooldown');
            assert(rateLimitRes.message.includes('Please wait'), 'Rate limit message includes cooldown guidance');
            // Negative: Wrong OTP verification
            try {
                yield defaultProvider.verifyAadhaarOtp({
                    harvesterId: testHarvesterId,
                    aadhaarNumber: testAadhaar,
                    transactionId: initRes.transactionId,
                    otp: '000000'
                });
                assert(false, 'Should reject wrong OTP');
            }
            catch (e) {
                assert(e.message.includes('Incorrect Aadhaar OTP') || e.message.includes('attempt(s) remaining'), 'Wrong OTP rejected with remaining attempts');
            }
            // Success: Correct OTP verification
            const verifyRes = yield defaultProvider.verifyAadhaarOtp({
                harvesterId: testHarvesterId,
                aadhaarNumber: testAadhaar,
                transactionId: initRes.transactionId,
                otp: initRes.devOtp
            });
            assert(verifyRes.success === true, 'Aadhaar OTP verification passed');
            assert(verifyRes.verified === true, 'Authoritative verified flag returned true');
            assert(verifyRes.maskedAadhaar === 'AADHAAR-***3821', 'Masked reference formatted as AADHAAR-***XXXX');
            assert(verifyRes.docHash.length === 64, 'Deterministic SHA-256 document checksum generated');
            // 3. Pluggable Providers (Signzy, HyperVerge, DigiO) Configuration Check
            console.log('\n--- 3. Pluggable Provider Configuration & Production Safety ---');
            // Signzy
            process.env.AADHAAR_PROVIDER = 'signzy';
            kyc_1.KycProviderFactory.resetProvider();
            const signzyProvider = kyc_1.KycProviderFactory.getProvider();
            assert(signzyProvider instanceof kyc_1.SignzyAadhaarProvider, 'Successfully switched to Signzy provider');
            assert(signzyProvider.isConfigured === false, 'Signzy flagged as unconfigured when env keys are absent');
            // Test production error guard when credentials are missing
            process.env.NODE_ENV = 'production';
            kyc_1.KycProviderFactory.resetProvider();
            try {
                kyc_1.KycProviderFactory.getProvider();
                assert(false, 'Should block unconfigured provider in production');
            }
            catch (e) {
                assert(e.message.includes('Aadhaar provider credentials/onboarding are required'), 'Production mode strictly requires valid provider credentials');
            }
            process.env.NODE_ENV = 'development';
            // HyperVerge
            process.env.AADHAAR_PROVIDER = 'hyperverge';
            kyc_1.KycProviderFactory.resetProvider();
            const hvProvider = kyc_1.KycProviderFactory.getProvider();
            assert(hvProvider instanceof kyc_1.HyperVergeAadhaarProvider, 'Successfully switched to HyperVerge provider');
            // DigiO
            process.env.AADHAAR_PROVIDER = 'digio';
            kyc_1.KycProviderFactory.resetProvider();
            const digioProvider = kyc_1.KycProviderFactory.getProvider();
            assert(digioProvider instanceof kyc_1.DigiOAadhaarProvider, 'Successfully switched to DigiO provider');
            // 4. End-to-End Verification Flow via VerificationService
            console.log('\n--- 4. End-to-End Verification Service & Authoritative Gate ---');
            process.env.AADHAAR_PROVIDER = 'sandbox';
            kyc_1.KycProviderFactory.resetProvider();
            const harvesterUser = `harv-e2e-${Date.now()}`;
            const initialStatus = yield verificationService_1.verificationService.getOrCreateVerification(harvesterUser);
            assert(initialStatus.governmentIdVerified === 'Not Started', 'Initial Government ID status is Not Started');
            const otpSent = yield verificationService_1.verificationService.sendAadhaarOtp(harvesterUser, '987654321098');
            assert(otpSent.success === true, 'Verification service sent OTP via KYC provider');
            const verifiedRecord = yield verificationService_1.verificationService.verifyAadhaarOtp(harvesterUser, '987654321098', otpSent.devOtp);
            assert(verifiedRecord.governmentIdVerified === 'Verified', 'Verification record updated to Verified in database');
            assert(verifiedRecord.governmentIdReference === 'AADHAAR-***1098', 'Masked reference persisted in DB');
            assert(verifiedRecord.governmentIdDocHash !== null && verifiedRecord.governmentIdDocHash.length === 64, 'SHA-256 hash persisted in DB');
            console.log('\n========================================');
            console.log(`TEST SUMMARY: ${passed} passed, ${failed} failed`);
            console.log('========================================\n');
            if (failed > 0) {
                process.exit(1);
            }
        }
        catch (error) {
            console.error('Fatal Test Error:', error);
            process.exit(1);
        }
        finally {
            yield prisma.$disconnect();
        }
    });
}
runKycTests();
