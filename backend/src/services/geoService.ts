export interface Coordinates {
  lat: number;
  lng: number;
}

/**
 * Parses coordinate strings in formats:
 * - "44.0521, -121.3153"
 * - "44.0521° N, 121.3153° W"
 * - "44.0521, 121.3153"
 */
export function parseCoordinates(coordStr?: string | null): Coordinates | null {
  if (!coordStr || typeof coordStr !== 'string') return null;

  const trimmed = coordStr.trim();
  if (!trimmed) return null;

  // Format: "Bend Industrial Center (44.0582, -121.3153)" or "44.0521, -121.3153"
  const embeddedMatch = trimmed.match(/(?:^|\(|\s)([-+]?\d{1,3}(?:\.\d+)?)\s*,\s*([-+]?\d{1,3}(?:\.\d+)?)(?:\)|\s|$)/);
  if (embeddedMatch) {
    const lat = parseFloat(embeddedMatch[1]);
    const lng = parseFloat(embeddedMatch[2]);
    if (!isNaN(lat) && !isNaN(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
      return { lat, lng };
    }
  }

  // Format: "44.0521° N, 121.3153° W"
  const degreeMatch = trimmed.match(/(\d+(?:\.\d+)?)\s*°?\s*([NS])\s*,\s*(\d+(?:\.\d+)?)\s*°?\s*([EW])/i);
  if (degreeMatch) {
    let lat = parseFloat(degreeMatch[1]);
    const latDir = degreeMatch[2].toUpperCase();
    if (latDir === 'S') lat = -lat;

    let lng = parseFloat(degreeMatch[3]);
    const lngDir = degreeMatch[4].toUpperCase();
    if (lngDir === 'W') lng = -lng;

    if (!isNaN(lat) && !isNaN(lng)) {
      return { lat, lng };
    }
  }

  // Known location defaults (fallback geocoding dictionary)
  const lower = trimmed.toLowerCase();
  if (lower.includes('bend') || lower.includes('cascade valley')) return { lat: 44.0582, lng: -121.3153 };
  if (lower.includes('corvallis')) return { lat: 44.5646, lng: -123.2620 };
  if (lower.includes('portland')) return { lat: 45.5152, lng: -122.6784 };
  if (lower.includes('eugene')) return { lat: 44.0521, lng: -123.0868 };
  if (lower.includes('salem')) return { lat: 44.9429, lng: -123.0351 };
  if (lower.includes('redmond')) return { lat: 44.2726, lng: -121.1739 };
  if (lower.includes('tigard')) return { lat: 45.4312, lng: -122.7712 };
  if (lower.includes('noida') || lower.includes('delhi')) return { lat: 28.6139, lng: 77.2090 };

  return null;
}

/**
 * Calculates geodesic distance between two points in Kilometers using Haversine formula
 */
export function calculateHaversineDistanceKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // Earth radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const d = R * c;
  return Math.round(d * 10) / 10; // 1 decimal place
}
