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
exports.OtherLocalProvider = void 0;
class OtherLocalProvider {
    constructor() {
        this.authority = 'OTHER_LOCAL';
        this.authorityName = 'Other / Local Registration';
        this.supportsAutomatedVerification = false;
    }
    /**
     * For local / regional / other associations that do not offer a public automated API gateway.
     * Does NOT fake automated verification. Explicitly marks record as 'Manual Verification Required'.
     */
    verifyRegistration(registrationIdRaw) {
        return __awaiter(this, void 0, void 0, function* () {
            const regId = (registrationIdRaw || '').trim().toUpperCase();
            if (!regId || regId.length < 3) {
                return {
                    success: false,
                    status: 'Failed',
                    authority: this.authority,
                    registrationId: regId,
                    authorityName: this.authorityName,
                    message: 'Registration ID must be at least 3 characters.',
                    requiresManualReview: false
                };
            }
            return {
                success: true,
                status: 'Manual Verification Required',
                authority: this.authority,
                registrationId: regId,
                authorityName: this.authorityName,
                message: 'Verification unavailable — manual verification required.',
                requiresManualReview: true,
                metadata: {
                    verifiedVia: 'Manual Association Review Queue',
                    registryType: 'OTHER_LOCAL'
                }
            };
        });
    }
}
exports.OtherLocalProvider = OtherLocalProvider;
