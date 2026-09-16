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
const express_1 = require("express");
const verificationService_1 = require("../services/verificationService");
const otpService_1 = require("../services/otpService");
const router = (0, express_1.Router)();
/**
 * GET /api/verification/harvester/status/:harvesterId
 * Retrieve current verification workflow status for a harvester
 */
router.get('/harvester/status/:harvesterId', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const harvesterId = String(req.params.harvesterId);
        const verification = yield verificationService_1.verificationService.getOrCreateVerification(harvesterId);
        res.json({ success: true, verification });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/harvester/start
 * Initialize or fetch existing verification record
 */
router.post('/harvester/start', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { harvesterId } = req.body;
        if (!harvesterId) {
            return res.status(400).json({ success: false, error: 'Harvester ID is required' });
        }
        const verification = yield verificationService_1.verificationService.getOrCreateVerification(harvesterId);
        res.json({ success: true, verification });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/harvester/aadhaar/send-otp
 * Step 1a: Send Aadhaar OTP to linked mobile
 */
router.post('/harvester/aadhaar/send-otp', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { harvesterId, aadhaarNumber } = req.body;
        if (!harvesterId || !aadhaarNumber) {
            return res.status(400).json({ success: false, error: 'harvesterId and aadhaarNumber are required' });
        }
        const result = yield verificationService_1.verificationService.sendAadhaarOtp(harvesterId, aadhaarNumber);
        if (!result.success) {
            return res.status(429).json(result);
        }
        res.json(result);
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/harvester/aadhaar/verify-otp
 * Step 1b: Verify Aadhaar OTP
 */
router.post('/harvester/aadhaar/verify-otp', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { harvesterId, aadhaarNumber, otp, transactionId } = req.body;
        if (!harvesterId || (!aadhaarNumber && !transactionId) || !otp) {
            return res.status(400).json({ success: false, error: 'harvesterId, otp, and aadhaarNumber (or transactionId) are required' });
        }
        const verification = yield verificationService_1.verificationService.verifyAadhaarOtp(harvesterId, aadhaarNumber, otp, transactionId);
        res.json({ success: true, message: 'Aadhaar Verified ✓', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/harvester/government-id
 * Step 1: Submit Government ID (Aadhaar / Standard)
 */
router.post('/harvester/government-id', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { harvesterId, documentType, documentNumber } = req.body;
        if (!harvesterId || !documentNumber) {
            return res.status(400).json({ success: false, error: 'harvesterId and documentNumber are required' });
        }
        const verification = yield verificationService_1.verificationService.submitGovernmentId(harvesterId, documentType, documentNumber);
        res.json({ success: true, message: 'Government ID submitted and verified.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/harvester/mobile/send-otp
 * POST /api/verification/mobile/send-otp
 * POST /api/verification/send-otp
 * Step 2a: Send Mobile OTP
 */
const handleGenericSendOtp = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { mobile } = req.body;
        if (!mobile) {
            return res.status(400).json({ success: false, error: 'Mobile number is required' });
        }
        const result = yield otpService_1.otpService.sendOtp(mobile);
        if (!result.success) {
            return res.status(429).json(result);
        }
        res.json(result);
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
});
router.post('/harvester/mobile/send-otp', handleGenericSendOtp);
router.post('/mobile/send-otp', handleGenericSendOtp);
router.post('/send-otp', handleGenericSendOtp);
/**
 * POST /api/verification/harvester/mobile/verify-otp
 * Step 2b: Verify Mobile OTP
 */
router.post('/harvester/mobile/verify-otp', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { harvesterId, mobile, otp } = req.body;
        if (!harvesterId || !mobile || !otp) {
            return res.status(400).json({ success: false, error: 'harvesterId, mobile, and otp are required' });
        }
        const verification = yield verificationService_1.verificationService.submitMobileVerification(harvesterId, mobile, otp);
        res.json({ success: true, message: 'Mobile verified successfully.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/mobile/verify-otp
 * POST /api/verification/verify-otp
 * Generic standalone OTP verification endpoint
 */
const handleGenericVerifyOtp = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { mobile, otp, sessionId } = req.body;
        if (!mobile || !otp) {
            return res.status(400).json({ success: false, error: 'mobile and otp are required' });
        }
        const result = yield otpService_1.otpService.verifyOtp(mobile, otp, sessionId);
        if (!result.success) {
            return res.status(400).json(result);
        }
        res.json(result);
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
});
router.post('/mobile/verify-otp', handleGenericVerifyOtp);
router.post('/verify-otp', handleGenericVerifyOtp);
/**
 * POST /api/verification/harvester/registration
 * Step 3: Submit Beekeeper Registration ID
 */
router.post('/harvester/registration', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { harvesterId, registrationId, registrationType } = req.body;
        if (!harvesterId || !registrationId) {
            return res.status(400).json({ success: false, error: 'harvesterId and registrationId are required' });
        }
        const verification = yield verificationService_1.verificationService.submitRegistrationId(harvesterId, registrationId, registrationType);
        res.json({ success: true, message: 'Beekeeper Registration verified.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/harvester/fssai
 * Step 3.5: Submit FSSAI License
 */
router.post('/harvester/fssai', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { harvesterId, fssaiLicense } = req.body;
        if (!harvesterId || !fssaiLicense) {
            return res.status(400).json({ success: false, error: 'harvesterId and fssaiLicense are required' });
        }
        const verification = yield verificationService_1.verificationService.submitHarvesterFssaiLicense(harvesterId, fssaiLicense);
        res.json({ success: true, message: 'FSSAI License verified.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/harvester/location
 * Step 4: Submit Apiary Location
 */
router.post('/harvester/location', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { harvesterId, apiaryName, apiaryLocation, apiaryCoordinates } = req.body;
        if (!harvesterId || !apiaryLocation) {
            return res.status(400).json({ success: false, error: 'harvesterId and apiaryLocation are required' });
        }
        const verification = yield verificationService_1.verificationService.submitApiaryLocation(harvesterId, apiaryName, apiaryLocation, apiaryCoordinates);
        res.json({ success: true, message: 'Apiary location verified.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/harvester/blockchain-verify
 * Step 5: Final Blockchain Verification Record
 */
router.post('/harvester/blockchain-verify', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { harvesterId } = req.body;
        if (!harvesterId) {
            return res.status(400).json({ success: false, error: 'harvesterId is required' });
        }
        const result = yield verificationService_1.verificationService.submitBlockchainVerification(harvesterId);
        res.json(Object.assign({ success: true, message: 'Harvester successfully verified and recorded on blockchain ledger.' }, result));
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/harvester/admin/review
 * Verifier / Admin manual review
 */
router.post('/harvester/admin/review', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { harvesterId, field, decision, notes } = req.body;
        if (!harvesterId || !decision) {
            return res.status(400).json({ success: false, error: 'harvesterId and decision (Verified/Rejected) are required' });
        }
        const updated = yield verificationService_1.verificationService.reviewVerification(harvesterId, field || 'all', decision, notes);
        res.json({ success: true, verification: updated });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * GET /api/verification/verify/harvester/:verificationId
 * GET /api/verify/harvester/:verificationId
 * Public verification endpoint for QR code scanners & certificate lookup
 */
router.get('/verify/harvester/:verificationId', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const verificationId = String(req.params.verificationId);
        if (!verificationId || verificationId === 'undefined') {
            return res.status(400).json({ success: false, found: false, message: 'Verification ID is required' });
        }
        const result = yield verificationService_1.verificationService.getPublicVerificationByVerificationId(verificationId);
        if (!result.found) {
            return res.status(404).json(Object.assign({ success: false }, result));
        }
        res.json(Object.assign({ success: true }, result));
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
// ═══════════════════════════════════════════════════════════════════════════
// COLLECTOR & PROCESSOR VERIFICATION ENDPOINTS (3/3 PARAMETERS)
// ═══════════════════════════════════════════════════════════════════════════
/**
 * GET /api/verification/collector/status/:collectorId
 * Get current verification record and status for Collector / Processor
 */
router.get('/collector/status/:collectorId', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const collectorId = String(req.params.collectorId);
        const verification = yield verificationService_1.verificationService.getOrCreateCollectorVerification(collectorId);
        res.json({ success: true, verification });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/collector/mobile/send-otp
 * Step 1a: Send OTP to collector mobile number
 */
router.post('/collector/mobile/send-otp', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { collectorId, mobile } = req.body;
        if (!collectorId || !mobile) {
            return res.status(400).json({ success: false, error: 'collectorId and mobile are required' });
        }
        const result = yield verificationService_1.verificationService.sendCollectorMobileOtp(collectorId, mobile);
        if (!result.success) {
            return res.status(429).json(result);
        }
        res.json(result);
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/collector/mobile/verify-otp
 * Step 1b: Verify OTP and save collector identity
 */
router.post('/collector/mobile/verify-otp', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { collectorId, mobile, otp, fullName } = req.body;
        if (!collectorId || !mobile || !otp) {
            return res.status(400).json({ success: false, error: 'collectorId, mobile, and otp are required' });
        }
        const verification = yield verificationService_1.verificationService.verifyCollectorMobileOtp(collectorId, mobile, otp, fullName);
        res.json({ success: true, message: 'Identity verified successfully.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/collector/business
 * Step 2: Submit and verify Business Information (Center Name & Center Address)
 */
router.post('/collector/business', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { collectorId, organizationName, facilityLocation, businessDetails } = req.body;
        if (!collectorId || !organizationName || !facilityLocation) {
            return res.status(400).json({ success: false, error: 'collectorId, organizationName, and facilityLocation are required' });
        }
        const verification = yield verificationService_1.verificationService.submitCollectorBusiness(collectorId, organizationName, facilityLocation, businessDetails);
        res.json({ success: true, message: 'Business details verified.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/verification/collector/kyc
 * Step 3: Real KYC / ID Verification (Government ID / Regulatory License)
 */
router.post('/collector/kyc', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { collectorId, governmentIdType, governmentIdNumber, licenseNumber } = req.body;
        if (!collectorId || !governmentIdNumber) {
            return res.status(400).json({ success: false, error: 'collectorId and governmentIdNumber are required' });
        }
        const verification = yield verificationService_1.verificationService.submitCollectorKyc(collectorId, governmentIdType, governmentIdNumber, licenseNumber);
        res.json({ success: true, message: 'KYC / License verified successfully.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
// ═════════════════════════════════════════════════════════════════════
// LAB TESTER VERIFICATION ENDPOINTS (3/3)
// ═════════════════════════════════════════════════════════════════════
router.get('/lab/status/:labId', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const labId = String(req.params.labId);
        const verification = yield verificationService_1.verificationService.getOrCreateLabVerification(labId);
        res.json({ success: true, verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
router.post('/lab/mobile/send-otp', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { labId, mobile } = req.body;
        if (!labId || !mobile) {
            return res.status(400).json({ success: false, error: 'labId and mobile are required' });
        }
        const result = yield verificationService_1.verificationService.sendLabMobileOtp(labId, mobile);
        res.json(result);
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
router.post('/lab/mobile/verify-otp', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { labId, mobile, otp, fullName } = req.body;
        if (!labId || !otp) {
            return res.status(400).json({ success: false, error: 'labId and otp are required' });
        }
        const verification = yield verificationService_1.verificationService.verifyLabMobileOtp(labId, otp, mobile, fullName);
        res.json({ success: true, message: 'Identity verified successfully.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
router.post('/lab/details', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { labId, labName, labAddress, labRegistrationNumber, accreditation } = req.body;
        if (!labId || !labName || !labAddress || !labRegistrationNumber) {
            return res.status(400).json({ success: false, error: 'labId, labName, labAddress, and labRegistrationNumber are required' });
        }
        const verification = yield verificationService_1.verificationService.submitLabDetails(labId, labName, labAddress, labRegistrationNumber, accreditation);
        res.json({ success: true, message: 'Laboratory details verified.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
router.post('/lab/kyc', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { labId, governmentIdType, governmentIdNumber, qualification, authorizedTestingDetails } = req.body;
        if (!labId || !governmentIdNumber) {
            return res.status(400).json({ success: false, error: 'labId and governmentIdNumber are required' });
        }
        const verification = yield verificationService_1.verificationService.submitLabKyc(labId, governmentIdType, governmentIdNumber, qualification, authorizedTestingDetails);
        res.json({ success: true, message: 'Lab Tester KYC & Qualification verified.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
// ═════════════════════════════════════════════════════════════════════
// PACKAGING MANAGER VERIFICATION ENDPOINTS (3/3)
// ═════════════════════════════════════════════════════════════════════
router.get('/packaging/status/:packagerId', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const packagerId = String(req.params.packagerId);
        const verification = yield verificationService_1.verificationService.getOrCreatePackagingVerification(packagerId);
        res.json({ success: true, verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
router.post('/packaging/mobile/send-otp', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { packagerId, mobile } = req.body;
        if (!packagerId || !mobile) {
            return res.status(400).json({ success: false, error: 'packagerId and mobile are required' });
        }
        const result = yield verificationService_1.verificationService.sendPackagingMobileOtp(packagerId, mobile);
        res.json(result);
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
router.post('/packaging/mobile/verify-otp', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { packagerId, mobile, otp, fullName } = req.body;
        if (!packagerId || !otp) {
            return res.status(400).json({ success: false, error: 'packagerId and otp are required' });
        }
        const verification = yield verificationService_1.verificationService.verifyPackagingMobileOtp(packagerId, otp, mobile, fullName);
        res.json({ success: true, message: 'Identity verified successfully.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
router.post('/packaging/details', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { packagerId, organizationName, facilityLocation, packagingLicenseNumber } = req.body;
        if (!packagerId || !organizationName || !facilityLocation || !packagingLicenseNumber) {
            return res.status(400).json({ success: false, error: 'packagerId, organizationName, facilityLocation, and packagingLicenseNumber are required' });
        }
        const verification = yield verificationService_1.verificationService.submitPackagingDetails(packagerId, organizationName, facilityLocation, packagingLicenseNumber);
        res.json({ success: true, message: 'Packaging facility details verified.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
router.post('/packaging/kyc', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { packagerId, governmentIdType, governmentIdNumber, authorizedPackagingDetails } = req.body;
        if (!packagerId || !governmentIdNumber) {
            return res.status(400).json({ success: false, error: 'packagerId and governmentIdNumber are required' });
        }
        const verification = yield verificationService_1.verificationService.submitPackagingKyc(packagerId, governmentIdType, governmentIdNumber, authorizedPackagingDetails);
        res.json({ success: true, message: 'Packaging Manager KYC & Scope verified.', verification });
    }
    catch (error) {
        res.status(400).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
exports.default = router;
