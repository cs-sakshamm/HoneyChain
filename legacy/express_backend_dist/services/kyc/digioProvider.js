"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
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
exports.DigiOAadhaarProvider = void 0;
const crypto = __importStar(require("crypto"));
class DigiOAadhaarProvider {
    constructor() {
        this.providerName = 'DigiO (UIDAI-Authorized KYC Provider)';
        this.clientId = process.env.AADHAAR_CLIENT_ID || process.env.DIGIO_CLIENT_ID;
        this.clientSecret = process.env.AADHAAR_API_SECRET || process.env.DIGIO_CLIENT_SECRET;
        this.isSandbox = process.env.AADHAAR_ENVIRONMENT === 'sandbox' || process.env.NODE_ENV !== 'production';
        this.baseUrl = process.env.AADHAAR_BASE_URL || (this.isSandbox ? 'https://ext.digio.in:444/v2' : 'https://api.digio.in/v2');
    }
    get isConfigured() {
        return Boolean(this.clientId && this.clientSecret);
    }
    getBasicAuthHeader() {
        return 'Basic ' + Buffer.from(`${this.clientId}:${this.clientSecret}`).toString('base64');
    }
    initiateAadhaarOtp(request) {
        return __awaiter(this, void 0, void 0, function* () {
            var _a;
            if (!this.isConfigured) {
                throw new Error('Aadhaar provider credentials/onboarding are required before production verification can be activated.');
            }
            const cleanAadhaar = (request.aadhaarNumber || '').replace(/\s+/g, '').trim();
            if (!cleanAadhaar || cleanAadhaar.length !== 12 || !/^\d{12}$/.test(cleanAadhaar)) {
                throw new Error('Please enter a valid 12-digit Aadhaar number.');
            }
            try {
                const response = yield fetch(`${this.baseUrl}/client/kyc/v2/aadhaar/otp`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': this.getBasicAuthHeader()
                    },
                    body: JSON.stringify({
                        aadhaar_id: cleanAadhaar,
                        customer_identifier: request.harvesterId
                    })
                });
                const data = yield response.json();
                if (!response.ok || !(data === null || data === void 0 ? void 0 : data.id)) {
                    throw new Error((data === null || data === void 0 ? void 0 : data.message) || ((_a = data === null || data === void 0 ? void 0 : data.error_details) === null || _a === void 0 ? void 0 : _a.message) || 'DigiO Aadhaar OTP request failed.');
                }
                return {
                    success: true,
                    transactionId: data.id || `DIGIO-TXN-${Date.now()}`,
                    message: 'OTP sent to your Aadhaar-linked mobile number.',
                    cooldownSeconds: 60,
                    expiresInSeconds: 300,
                    providerName: this.providerName
                };
            }
            catch (err) {
                throw new Error((err === null || err === void 0 ? void 0 : err.message) || 'Failed to communicate with DigiO Aadhaar provider.');
            }
        });
    }
    verifyAadhaarOtp(request) {
        return __awaiter(this, void 0, void 0, function* () {
            var _a, _b, _c, _d, _e, _f, _g, _h;
            if (!this.isConfigured) {
                throw new Error('Aadhaar provider credentials/onboarding are required before production verification can be activated.');
            }
            const cleanAadhaar = (request.aadhaarNumber || '').replace(/\s+/g, '').trim();
            const cleanOtp = (request.otp || '').trim();
            try {
                const response = yield fetch(`${this.baseUrl}/client/kyc/v2/aadhaar/verify`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': this.getBasicAuthHeader()
                    },
                    body: JSON.stringify({
                        id: request.transactionId,
                        otp: cleanOtp
                    })
                });
                const data = yield response.json();
                if (!response.ok || (data === null || data === void 0 ? void 0 : data.status) !== 'SUCCESS') {
                    throw new Error((data === null || data === void 0 ? void 0 : data.message) || ((_a = data === null || data === void 0 ? void 0 : data.error_details) === null || _a === void 0 ? void 0 : _a.message) || 'DigiO Aadhaar OTP validation failed.');
                }
                const last4 = cleanAadhaar.slice(-4);
                const maskedAadhaar = `AADHAAR-***${last4}`;
                const docHash = crypto.createHash('sha256').update(cleanAadhaar).digest('hex');
                return {
                    success: true,
                    verified: true,
                    maskedAadhaar,
                    docHash,
                    providerName: this.providerName,
                    transactionId: request.transactionId,
                    referenceId: data.reference_id,
                    kycData: {
                        name: (_b = data.details) === null || _b === void 0 ? void 0 : _b.name,
                        gender: (_c = data.details) === null || _c === void 0 ? void 0 : _c.gender,
                        dob: (_d = data.details) === null || _d === void 0 ? void 0 : _d.dob,
                        careOf: (_e = data.details) === null || _e === void 0 ? void 0 : _e.care_of,
                        address: (_f = data.details) === null || _f === void 0 ? void 0 : _f.address,
                        state: (_g = data.details) === null || _g === void 0 ? void 0 : _g.state,
                        pincode: (_h = data.details) === null || _h === void 0 ? void 0 : _h.pincode
                    },
                    message: 'Aadhaar Verified ✓'
                };
            }
            catch (err) {
                throw new Error((err === null || err === void 0 ? void 0 : err.message) || 'Failed to verify OTP with DigiO Aadhaar provider.');
            }
        });
    }
}
exports.DigiOAadhaarProvider = DigiOAadhaarProvider;
