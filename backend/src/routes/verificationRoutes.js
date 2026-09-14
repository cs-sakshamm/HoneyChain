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
 * POST /api/verification/harvester/government-id
 * Step 1: Submit Government ID
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
 * Step 2a: Send Mobile OTP
 */
router.post('/harvester/mobile/send-otp', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
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
}));
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
exports.default = router;
