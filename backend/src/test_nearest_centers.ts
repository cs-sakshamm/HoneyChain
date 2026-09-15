import assert from 'assert';
import { calculateHaversineDistanceKm, parseCoordinates } from './services/geoService';

async function runTests() {
  console.log('🧪 Starting Nearest Center Geo-Service Automated Tests...\n');

  // 1. Test Coordinate Parsing
  console.log('--- 1. Testing Coordinate Parsing ---');
  const coord1 = parseCoordinates('44.0521, -121.3153');
  assert(coord1 !== null, 'Parses standard comma-separated coordinates');
  assert.strictEqual(coord1?.lat, 44.0521, 'Latitude parsed correctly');
  assert.strictEqual(coord1?.lng, -121.3153, 'Longitude parsed correctly');
  console.log('  ✅ PASS: Standard coordinate parsing');

  const coord2 = parseCoordinates('44.0521° N, 121.3153° W');
  assert(coord2 !== null, 'Parses degree formatted coordinates');
  assert.strictEqual(coord2?.lat, 44.0521, 'Degree latitude parsed correctly');
  assert.strictEqual(coord2?.lng, -121.3153, 'Degree longitude parsed correctly');
  console.log('  ✅ PASS: Degree notation coordinate parsing');

  const coord3 = parseCoordinates('Bend Industrial Park, OR');
  assert(coord3 !== null, 'Parses known location name fallback');
  console.log('  ✅ PASS: Known location fallback geocoding');

  // 2. Test Haversine Distance
  console.log('\n--- 2. Testing Haversine Distance ---');
  // Bend (44.0582, -121.3153) to Redmond (44.2726, -121.1739) ~ 26 km
  const distBendRedmond = calculateHaversineDistanceKm(44.0582, -121.3153, 44.2726, -121.1739);
  assert(distBendRedmond > 20 && distBendRedmond < 30, `Distance is realistic: ${distBendRedmond} km`);
  console.log(`  ✅ PASS: Bend to Redmond distance: ${distBendRedmond} km`);

  // Bend to Corvallis (44.5646, -123.2620) ~ 164 km
  const distBendCorvallis = calculateHaversineDistanceKm(44.0582, -121.3153, 44.5646, -123.2620);
  assert(distBendCorvallis > 150 && distBendCorvallis < 180, `Distance is realistic: ${distBendCorvallis} km`);
  console.log(`  ✅ PASS: Bend to Corvallis distance: ${distBendCorvallis} km`);

  // Distance sorting test
  assert(distBendRedmond < distBendCorvallis, 'Redmond is correctly closer than Corvallis');
  console.log('  ✅ PASS: Ascending distance ordering verified');

  console.log('\n🎉 All GeoService Distance & Nearest Center Tests PASSED successfully!');
}

runTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
