import { SmsProviderFactory, SandboxSmsProvider, TwoFactorOtpProvider, Msg91OtpProvider } from './services/sms';
import { verificationService } from './services/verificationService';
import { otpService } from './services/otpService';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function runSmsProviderTests() {
  console.log('=== Starting SMS OTP Provider System Automated Tests ===\n');

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string) {
    if (condition) {
      console.log(`✓ PASS: ${testName}`);
      passed++;
    } else {
      console.error(`✗ FAIL: ${testName}`);
      failed++;
    }
  }

  try {
    const testPhone = `+9198765${Math.floor(10000 + Math.random() * 90000)}`;
    await prisma.mobileOtp.deleteMany({ where: { mobile: { in: [testPhone, '+919988776655'] } } });

    // 1. Provider Factory Default
    console.log('--- 1. Provider Factory & Default Sandbox ---');
    const savedApiKey = process.env.MOBILE_OTP_API_KEY || process.env.OTP_API_KEY;
    delete process.env.OTP_PROVIDER;
    delete process.env.MOBILE_OTP_API_KEY;
    delete process.env.OTP_API_KEY;
    delete process.env.TWOFACTOR_API_KEY;
    SmsProviderFactory.resetProvider();
    const defaultProvider = SmsProviderFactory.getProvider();
    assert(defaultProvider instanceof SandboxSmsProvider, 'Default provider is SandboxSmsProvider');
    assert(defaultProvider.isConfigured === true, 'Sandbox provider is always configured for dev/test');
    assert(defaultProvider.isSandbox === true, 'Sandbox provider is flagged as isSandbox');

    // 2. Sandbox Provider Validation & OTP Flow
    console.log('\n--- 2. Sandbox SMS OTP Dispatch & Validation ---');

    // Negative: Invalid Mobile Number
    const invalidSendRes = await defaultProvider.sendOtp('123');
    assert(invalidSendRes.success === false, 'Rejects invalid mobile number length (<10 digits)');

    // Success: Send OTP
    const sendRes = await defaultProvider.sendOtp(testPhone);
    assert(sendRes.success === true, 'SMS OTP dispatch succeeded');
    assert(sendRes.sessionId !== undefined && sendRes.sessionId.startsWith('SESSION-2F-SBX-'), 'Unique SMS session ID generated');
    assert(sendRes.message.includes(`OTP sent to ${testPhone}`), 'User-facing message indicates OTP dispatched');
    assert(sendRes.cooldownSeconds === 60, '60-second cooldown returned');
    assert(sendRes.devOtp !== undefined && sendRes.devOtp.length === 6, '6-digit SMS OTP generated for development');

    // Rate limiting: Duplicate send within 60s cooldown
    const rateLimitRes = await defaultProvider.sendOtp(testPhone);
    assert(rateLimitRes.success === false, 'Rate limiter prevents duplicate OTP sends during cooldown');
    assert(rateLimitRes.message.includes('Please wait'), 'Rate limit message includes cooldown guidance');

    // Negative: Wrong OTP verification
    const wrongVerifyRes = await defaultProvider.verifyOtp(testPhone, '000000', sendRes.sessionId);
    assert(wrongVerifyRes.success === false, 'Wrong OTP rejected');
    assert(wrongVerifyRes.message.includes('Incorrect verification code') || wrongVerifyRes.message.includes('attempt'), 'Wrong OTP response gives clear guidance');

    // Positive: Correct OTP verification
    const verifyRes = await defaultProvider.verifyOtp(testPhone, sendRes.devOtp!, sendRes.sessionId);
    assert(verifyRes.success === true, 'Valid OTP successfully verified');
    assert(verifyRes.verified === true, 'verified is true on verification success');

    // 3. Provider Switching via Environment Variables
    console.log('\n--- 3. Provider Switching (2Factor, MSG91, Sandbox) ---');
    
    // 2Factor instantiation
    process.env.OTP_PROVIDER = '2factor';
    process.env.TWOFACTOR_API_KEY = 'mock_2factor_key_test';
    SmsProviderFactory.resetProvider();
    const twoFactorProvider = SmsProviderFactory.getProvider();
    assert(twoFactorProvider instanceof TwoFactorOtpProvider, 'Factory instantiates TwoFactorOtpProvider when OTP_PROVIDER=2factor');
    assert(twoFactorProvider.providerName.includes('2Factor'), 'Provider name identifies 2Factor');
    assert(twoFactorProvider.isConfigured === true, '2Factor provider is configured when API key is present');

    // MSG91 instantiation
    process.env.OTP_PROVIDER = 'msg91';
    process.env.MSG91_AUTH_KEY = 'mock_msg91_key_test';
    SmsProviderFactory.resetProvider();
    const msg91Provider = SmsProviderFactory.getProvider();
    assert(msg91Provider instanceof Msg91OtpProvider, 'Factory instantiates Msg91OtpProvider when OTP_PROVIDER=msg91');
    assert(msg91Provider.providerName.includes('MSG91'), 'Provider name identifies MSG91');
    assert(msg91Provider.isConfigured === true, 'MSG91 provider is configured when AUTH key is present');

    // 4. Production Security Gate
    console.log('\n--- 4. Production Security Enforcement ---');
    const oldNodeEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    delete process.env.TWOFACTOR_API_KEY;
    delete process.env.MSG91_AUTH_KEY;
    process.env.OTP_PROVIDER = '2factor';
    SmsProviderFactory.resetProvider();

    try {
      SmsProviderFactory.getProvider();
      assert(false, 'Should throw error in production when credentials missing');
    } catch (e: any) {
      assert(e.message.includes('SMS OTP provider credentials') && e.message.includes('DLT onboarding'), 'Production throws clear missing credentials and DLT onboarding error');
    }

    // Restore environment
    process.env.NODE_ENV = oldNodeEnv;
    delete process.env.OTP_PROVIDER;
    delete process.env.TWOFACTOR_API_KEY;
    delete process.env.MSG91_AUTH_KEY;
    SmsProviderFactory.resetProvider();

    // 5. VerificationService Integration & Database User Linking
    console.log('\n--- 5. VerificationService Integration & Database User Linking ---');
    const testUser = await prisma.user.create({
      data: {
        email: `sms-test-${Date.now()}@honeychain.org`,
        name: 'SMS Test Harvester',
        role: 'HARVESTER',
      }
    });

    const linkedHarvesterId = testUser.id;
    const testServicePhone = `+9199887${Math.floor(10000 + Math.random() * 90000)}`;

    // Send OTP via otpService
    const serviceSendRes = await otpService.sendOtp(testServicePhone);
    assert(serviceSendRes.success === true, 'otpService.sendOtp succeeds');
    assert(serviceSendRes.sessionId !== undefined && serviceSendRes.sessionId.length > 0, 'otpService returns session ID');

    // Submit verification through verificationService
    const record = await verificationService.submitMobileVerification(
      linkedHarvesterId,
      testServicePhone,
      serviceSendRes.devOtp!
    );

    assert(record.mobileVerified === 'Verified', 'Verification record has mobileVerified = "Verified"');
    assert(record.mobileNumber === testServicePhone, 'Verification record stores sanitized mobile number');

    // Verify User record was updated with verified phone
    const updatedUser = await prisma.user.findUnique({ where: { id: linkedHarvesterId } });
    assert(updatedUser?.phone === testServicePhone, 'User model phone field updated to verified phone number');

    // Clean up test records
    await prisma.harvesterVerification.deleteMany({ where: { harvesterId: linkedHarvesterId } });
    await prisma.user.delete({ where: { id: linkedHarvesterId } });
    await prisma.mobileOtp.deleteMany({ where: { mobile: { in: [testPhone, testServicePhone] } } });

  } catch (error: any) {
    console.error('Test execution error:', error);
    failed++;
  } finally {
    await prisma.$disconnect();
  }

  console.log('\n=============================================');
  console.log(`Results: ${passed} PASSED, ${failed} FAILED`);
  console.log('=============================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runSmsProviderTests();
