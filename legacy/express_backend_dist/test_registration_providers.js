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
const registration_1 = require("./services/registration");
const authRoutes_1 = require("./routes/authRoutes");
const verificationService_1 = require("./services/verificationService");
const profileService_1 = require("./services/profileService");
const client_1 = require("@prisma/client");
const prisma = new client_1.PrismaClient();
function runRegistrationTests() {
    return __awaiter(this, void 0, void 0, function* () {
        console.log('=== Starting Beekeeper Registration & Location Verification Automated Tests ===\n');
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
            // ── 1. Registration Provider Factory & Resolution ──
            console.log('--- 1. Registration Authority Factory Resolution ---');
            const stateProvider = registration_1.RegistrationProviderFactory.getProvider('STATE_AGRICULTURE');
            assert(stateProvider instanceof registration_1.StateAgricultureProvider, 'Resolves StateAgricultureProvider for STATE_AGRICULTURE');
            assert(stateProvider.authorityName === 'State Department of Agriculture', 'Authority name is "State Department of Agriculture"');
            const nhpProvider = registration_1.RegistrationProviderFactory.getProvider('NATIONAL_HONEY_PRODUCERS');
            assert(nhpProvider instanceof registration_1.NationalHoneyProducersProvider, 'Resolves NationalHoneyProducersProvider for NATIONAL_HONEY_PRODUCERS');
            assert(nhpProvider.authorityName === 'National Honey Producers', 'Authority name is "National Honey Producers"');
            const orgProvider = registration_1.RegistrationProviderFactory.getProvider('ORGANIC_CERTIFICATION_BOARD');
            assert(orgProvider instanceof registration_1.OrganicCertificationBoardProvider, 'Resolves OrganicCertificationBoardProvider for ORGANIC_CERTIFICATION_BOARD');
            assert(orgProvider.authorityName === 'Organic Certification Board', 'Authority name is "Organic Certification Board"');
            const otherProvider = registration_1.RegistrationProviderFactory.getProvider('OTHER_LOCAL');
            assert(otherProvider instanceof registration_1.OtherLocalProvider, 'Resolves OtherLocalProvider for OTHER_LOCAL');
            assert(otherProvider.authorityName === 'Other / Local Registration', 'Authority name is "Other / Local Registration"');
            assert(otherProvider.supportsAutomatedVerification === false, 'OTHER_LOCAL indicates automated verification is not supported');
            // ── 2. State Department of Agriculture Validation ──
            console.log('\n--- 2. State Department of Agriculture Provider Validation ---');
            // Short ID rejection
            const stateShort = yield stateProvider.verifyRegistration('AB');
            assert(stateShort.success === false, 'Rejects short State Agriculture ID (<5 chars)');
            // Dummy ID rejection
            const stateDummy = yield stateProvider.verifyRegistration('BK123456');
            assert(stateDummy.success === false, 'Rejects dummy/fake ID BK123456');
            assert(stateDummy.message.includes('Dummy or placeholder'), 'Returns dummy rejection guidance');
            const stateDummy2 = yield stateProvider.verifyRegistration('BEE2026001');
            assert(stateDummy2.success === false, 'Rejects dummy/fake ID BEE2026001');
            // Valid State Agriculture ID
            const stateValid = yield stateProvider.verifyRegistration('AGRI-UP-2026-9812');
            assert(stateValid.success === true, 'Accepts authentic State Agriculture ID AGRI-UP-2026-9812');
            assert(stateValid.status === 'Verified', 'Sets status to "Verified"');
            assert(stateValid.requiresManualReview === false, 'Automated verification succeeds without manual review');
            // ── 3. National Honey Producers Provider Validation ──
            console.log('\n--- 3. National Honey Producers Provider Validation ---');
            const nhpDummy = yield nhpProvider.verifyRegistration('BK123456');
            assert(nhpDummy.success === false, 'NHP rejects dummy ID');
            const nhpValid = yield nhpProvider.verifyRegistration('NHP-IND-2026-8812');
            assert(nhpValid.success === true, 'Accepts authentic NHP ID NHP-IND-2026-8812');
            assert(nhpValid.status === 'Verified', 'Sets status to "Verified"');
            // ── 4. Organic Certification Board Provider Validation ──
            console.log('\n--- 4. Organic Certification Board Provider Validation ---');
            const orgDummy = yield orgProvider.verifyRegistration('DUMMY');
            assert(orgDummy.success === false, 'Organic Board rejects dummy ID');
            const orgValid = yield orgProvider.verifyRegistration('ORG-NPOP-2026-9041');
            assert(orgValid.success === true, 'Accepts authentic Organic Certificate ID ORG-NPOP-2026-9041');
            assert(orgValid.status === 'Verified', 'Sets status to "Verified"');
            // ── 5. Other / Local Registration — Fallback & No Fake Verification ──
            console.log('\n--- 5. Other / Local Registration Fallback & Manual Review ---');
            const otherRes = yield otherProvider.verifyRegistration('LOCAL-COOP-4412');
            assert(otherRes.success === true, 'Other / Local registration request processed');
            assert(otherRes.status === 'Manual Verification Required', 'Status is strictly "Manual Verification Required" (does not fake automated verification)');
            assert(otherRes.message === 'Verification unavailable — manual verification required.', 'Message is exactly "Verification unavailable — manual verification required."');
            assert(otherRes.requiresManualReview === true, 'requiresManualReview is true');
            // ── 6. Unique HoneyChain Beekeeper ID (HC-BK-XXXXXXXX) ──
            console.log('\n--- 6. HoneyChain Beekeeper ID Format & Uniqueness ---');
            const bkrId1 = yield (0, authRoutes_1.generateUniqueBeekeeperId)();
            const bkrId2 = yield (0, authRoutes_1.generateUniqueBeekeeperId)();
            assert(/^HC-BK-[0-9A-F]{8}$/.test(bkrId1), `Beekeeper ID ${bkrId1} matches HC-BK-XXXXXXXX format (8 hex uppercase characters)`);
            assert(/^HC-BK-[0-9A-F]{8}$/.test(bkrId2), `Beekeeper ID ${bkrId2} matches HC-BK-XXXXXXXX format`);
            assert(bkrId1 !== bkrId2, 'Two generated Beekeeper IDs are distinct and globally collision-resistant');
            // ── 7. VerificationService End-to-End Registration & Location ──
            console.log('\n--- 7. VerificationService Integration & User Profile Sync ---');
            const testUser = yield prisma.user.create({
                data: {
                    email: `reg-test-${Date.now()}@honeychain.org`,
                    name: 'Registration Test Beekeeper',
                    role: 'HARVESTER',
                    beekeeperId: bkrId1,
                }
            });
            const harvesterId = testUser.id;
            // Submit State Agriculture Registration ID
            const regRecord = yield verificationService_1.verificationService.submitRegistrationId(harvesterId, 'AGRI-UP-2026-9812', 'STATE_AGRICULTURE');
            assert(regRecord.registrationId === 'AGRI-UP-2026-9812', 'Stores external registration ID');
            assert(regRecord.registrationType === 'STATE_AGRICULTURE', 'Stores authority type STATE_AGRICULTURE');
            assert(regRecord.registrationVerified === 'Verified', 'Sets registrationVerified = "Verified" in database');
            // Submit Location with State, District, Village/City
            const locRecord = yield verificationService_1.verificationService.submitApiaryLocation(harvesterId, 'Primary Apiary #1', 'Greater Noida, Gautam Buddh Nagar, Uttar Pradesh', '28.4744, 77.5040');
            assert(locRecord.apiaryLocation === 'Greater Noida, Gautam Buddh Nagar, Uttar Pradesh', 'Stores formatted location');
            assert(locRecord.locationVerified === 'Verified', 'Sets locationVerified = "Verified"');
            // Verify User model was synced with facilityLocation
            const updatedUser = yield prisma.user.findUnique({ where: { id: harvesterId } });
            assert((updatedUser === null || updatedUser === void 0 ? void 0 : updatedUser.facilityLocation) === 'Greater Noida, Gautam Buddh Nagar, Uttar Pradesh', 'User.facilityLocation synced with submitted location');
            // ── 8. Profile Completion Gate Checks ──
            console.log('\n--- 8. Profile Completion & Harvester Verification Gates ---');
            // Harvester profile completeness check (name, email, phone)
            assert((0, profileService_1.isUserProfileComplete)(updatedUser) === false, 'Incomplete user (missing phone) is rejected by profile gate');
            yield prisma.user.update({
                where: { id: harvesterId },
                data: { phone: '+919876543210' }
            });
            const completeUser = yield prisma.user.findUnique({ where: { id: harvesterId } });
            assert((0, profileService_1.isUserProfileComplete)(completeUser) === true, 'Complete user with name, email, phone passes profile gate');
            // Harvester verification gate: check all 5 parameters
            const partialVerification = yield prisma.harvesterVerification.findUnique({ where: { harvesterId } });
            assert((0, profileService_1.isHarvesterFullyVerified)(partialVerification) === false, 'Partial verification correctly blocked from hive creation');
            // Clean up
            yield prisma.harvesterVerification.deleteMany({ where: { harvesterId } });
            yield prisma.user.delete({ where: { id: harvesterId } });
        }
        catch (error) {
            console.error('Test execution error:', error);
            failed++;
        }
        finally {
            yield prisma.$disconnect();
        }
        console.log('\n=============================================');
        console.log(`Results: ${passed} PASSED, ${failed} FAILED`);
        console.log('=============================================\n');
        if (failed > 0) {
            process.exit(1);
        }
    });
}
runRegistrationTests();
