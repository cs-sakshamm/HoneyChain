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
exports.RegistrationProviderFactory = void 0;
const stateAgricultureProvider_1 = require("./stateAgricultureProvider");
const nationalHoneyProducersProvider_1 = require("./nationalHoneyProducersProvider");
const organicCertificationBoardProvider_1 = require("./organicCertificationBoardProvider");
const otherLocalProvider_1 = require("./otherLocalProvider");
class RegistrationProviderFactory {
    /**
     * Normalize input authority string to strongly typed RegistrationAuthority enum
     */
    static normalizeAuthority(authorityRaw) {
        if (!authorityRaw)
            return 'STATE_AGRICULTURE';
        const norm = authorityRaw.toUpperCase().trim().replace(/[-\s]/g, '_');
        if (norm.includes('AGRICULTURE') || norm === 'STATE_REGISTRY' || norm === 'STATE_AGRICULTURE') {
            return 'STATE_AGRICULTURE';
        }
        if (norm.includes('PRODUCERS') || norm.includes('NATIONAL') || norm === 'COOPERATIVE' || norm === 'NATIONAL_HONEY_PRODUCERS') {
            return 'NATIONAL_HONEY_PRODUCERS';
        }
        if (norm.includes('ORGANIC') || norm.includes('APICULTURE') || norm === 'APICULTURE_BOARD' || norm === 'ORGANIC_CERTIFICATION_BOARD') {
            return 'ORGANIC_CERTIFICATION_BOARD';
        }
        return 'OTHER_LOCAL';
    }
    /**
     * Get provider instance for authority
     */
    static getProvider(authorityRaw) {
        const authority = this.normalizeAuthority(authorityRaw);
        const provider = this.providers.get(authority);
        if (!provider) {
            return new otherLocalProvider_1.OtherLocalProvider();
        }
        return provider;
    }
    /**
     * Execute registration verification via appropriate authority provider
     */
    static verifyRegistration(registrationId, authorityRaw) {
        return __awaiter(this, void 0, void 0, function* () {
            const provider = this.getProvider(authorityRaw);
            return provider.verifyRegistration(registrationId);
        });
    }
}
exports.RegistrationProviderFactory = RegistrationProviderFactory;
RegistrationProviderFactory.providers = new Map([
    ['STATE_AGRICULTURE', new stateAgricultureProvider_1.StateAgricultureProvider()],
    ['NATIONAL_HONEY_PRODUCERS', new nationalHoneyProducersProvider_1.NationalHoneyProducersProvider()],
    ['ORGANIC_CERTIFICATION_BOARD', new organicCertificationBoardProvider_1.OrganicCertificationBoardProvider()],
    ['OTHER_LOCAL', new otherLocalProvider_1.OtherLocalProvider()]
]);
