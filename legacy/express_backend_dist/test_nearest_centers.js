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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const assert_1 = __importDefault(require("assert"));
const geoService_1 = require("./services/geoService");
function runTests() {
    return __awaiter(this, void 0, void 0, function* () {
        console.log('🧪 Starting Nearest Center Geo-Service Automated Tests...\n');
        // 1. Test Coordinate Parsing
        console.log('--- 1. Testing Coordinate Parsing ---');
        const coord1 = (0, geoService_1.parseCoordinates)('44.0521, -121.3153');
        (0, assert_1.default)(coord1 !== null, 'Parses standard comma-separated coordinates');
        assert_1.default.strictEqual(coord1 === null || coord1 === void 0 ? void 0 : coord1.lat, 44.0521, 'Latitude parsed correctly');
        assert_1.default.strictEqual(coord1 === null || coord1 === void 0 ? void 0 : coord1.lng, -121.3153, 'Longitude parsed correctly');
        console.log('  ✅ PASS: Standard coordinate parsing');
        const coord2 = (0, geoService_1.parseCoordinates)('44.0521° N, 121.3153° W');
        (0, assert_1.default)(coord2 !== null, 'Parses degree formatted coordinates');
        assert_1.default.strictEqual(coord2 === null || coord2 === void 0 ? void 0 : coord2.lat, 44.0521, 'Degree latitude parsed correctly');
        assert_1.default.strictEqual(coord2 === null || coord2 === void 0 ? void 0 : coord2.lng, -121.3153, 'Degree longitude parsed correctly');
        console.log('  ✅ PASS: Degree notation coordinate parsing');
        const coord3 = (0, geoService_1.parseCoordinates)('Bend Industrial Park, OR');
        (0, assert_1.default)(coord3 !== null, 'Parses known location name fallback');
        console.log('  ✅ PASS: Known location fallback geocoding');
        // 2. Test Haversine Distance
        console.log('\n--- 2. Testing Haversine Distance ---');
        // Bend (44.0582, -121.3153) to Redmond (44.2726, -121.1739) ~ 26 km
        const distBendRedmond = (0, geoService_1.calculateHaversineDistanceKm)(44.0582, -121.3153, 44.2726, -121.1739);
        (0, assert_1.default)(distBendRedmond > 20 && distBendRedmond < 30, `Distance is realistic: ${distBendRedmond} km`);
        console.log(`  ✅ PASS: Bend to Redmond distance: ${distBendRedmond} km`);
        // Bend to Corvallis (44.5646, -123.2620) ~ 164 km
        const distBendCorvallis = (0, geoService_1.calculateHaversineDistanceKm)(44.0582, -121.3153, 44.5646, -123.2620);
        (0, assert_1.default)(distBendCorvallis > 150 && distBendCorvallis < 180, `Distance is realistic: ${distBendCorvallis} km`);
        console.log(`  ✅ PASS: Bend to Corvallis distance: ${distBendCorvallis} km`);
        // Distance sorting test
        (0, assert_1.default)(distBendRedmond < distBendCorvallis, 'Redmond is correctly closer than Corvallis');
        console.log('  ✅ PASS: Ascending distance ordering verified');
        console.log('\n🎉 All GeoService Distance & Nearest Center Tests PASSED successfully!');
    });
}
runTests().catch((err) => {
    console.error('❌ Test failed:', err);
    process.exit(1);
});
