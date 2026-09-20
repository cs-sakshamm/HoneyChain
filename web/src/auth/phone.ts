/**
 * Centralized country-code & phone-number utilities for the HoneyChain web
 * verifier. Mirrors `mobile_app/lib/core/utils/phone_utils.dart` — keep the
 * two in sync when editing.
 *
 * Single source of truth for:
 *  - the supported country list (flag, ISO code, name, calling code),
 *  - E.164 normalization (+[cc][nsn]) per selected country,
 *  - per-country validation of the national number,
 *  - duplicate-country-code stripping when the user pastes a full number.
 */

export interface CountryInfo {
  isoCode: string;
  name: string;
  flag: string;
  /** Digits only, no '+'. */
  callingCode: string;
  /** Regular expression over the digits-only national number. */
  nsnPattern: string;
  nsnMinLength: number;
  nsnMaxLength: number;
  /** Example formatting shown as the input hint. */
  nsnHint: string;
}

/** Supported countries (name-sorted; India first as the project default). */
export const SUPPORTED_COUNTRIES: CountryInfo[] = [
  {
    isoCode: 'IN',
    name: 'India',
    flag: '🇮🇳',
    callingCode: '91',
    nsnPattern: '^[6-9]\\d{9}$',
    nsnMinLength: 10,
    nsnMaxLength: 10,
    nsnHint: '98765 43210',
  },
  {
    isoCode: 'US',
    name: 'United States',
    flag: '🇺🇸',
    callingCode: '1',
    nsnPattern: '^\\d{10}$',
    nsnMinLength: 10,
    nsnMaxLength: 10,
    nsnHint: '(555) 123-4567',
  },
  {
    isoCode: 'GB',
    name: 'United Kingdom',
    flag: '🇬🇧',
    callingCode: '44',
    nsnPattern: '^\\d{10}$',
    nsnMinLength: 10,
    nsnMaxLength: 10,
    nsnHint: '7400 123456',
  },
  {
    isoCode: 'AE',
    name: 'United Arab Emirates',
    flag: '🇦🇪',
    callingCode: '971',
    nsnPattern: '^\\d{8,9}$',
    nsnMinLength: 8,
    nsnMaxLength: 9,
    nsnHint: '50 123 4567',
  },
  {
    isoCode: 'SG',
    name: 'Singapore',
    flag: '🇸🇬',
    callingCode: '65',
    nsnPattern: '^[689]\\d{7}$',
    nsnMinLength: 8,
    nsnMaxLength: 8,
    nsnHint: '8123 4567',
  },
  {
    isoCode: 'AU',
    name: 'Australia',
    flag: '🇦🇺',
    callingCode: '61',
    nsnPattern: '^\\d{9}$',
    nsnMinLength: 9,
    nsnMaxLength: 9,
    nsnHint: '412 345 678',
  },
];

/** Default selection (project requires India as the default market). */
export const DEFAULT_COUNTRY: CountryInfo = SUPPORTED_COUNTRIES[0];

export function countryByIso(iso: string | null | undefined): CountryInfo {
  const needle = (iso ?? '').trim().toUpperCase();
  return SUPPORTED_COUNTRIES.find((c) => c.isoCode === needle) ?? DEFAULT_COUNTRY;
}

export function dialCode(country: CountryInfo): string {
  return `+${country.callingCode}`;
}

/**
 * Removes a duplicated country code from the national number, e.g. the user
 * pasted `+91 9876543210` while +91 is already selected. Only strips when
 * what remains still validates for the country, so genuine numbers that
 * begin with the same digits are not mangled.
 */
function stripDuplicateCountryCode(digits: string, country: CountryInfo): string {
  if (!digits.startsWith(country.callingCode)) return digits;
  const remainder = digits.slice(country.callingCode.length);
  if (!remainder) return digits;
  const trunkless = remainder.startsWith('0') ? remainder.slice(1) : remainder;
  if (new RegExp(country.nsnPattern).test(trunkless)) return trunkless;
  if (new RegExp(country.nsnPattern).test(remainder)) return remainder;
  return digits;
}

export interface PhoneNormalization {
  /** Digits-only national number (right of the calling code). */
  nsn: string;
  /** Full E.164 string: +[countryCallingCode][nsn]. */
  e164: string;
  isValid: boolean;
}

/**
 * Normalizes raw user input against `country` and validates it. Handles
 * separators, a leading '+', duplicated country codes and trunk prefixes.
 * The returned `e164` is always the value to send to Firebase / backend.
 */
export function normalizePhoneForCountry(
  raw: string,
  country: CountryInfo
): PhoneNormalization {
  const digits = raw.replace(/\D/g, '');
  const hadPlus = raw.trim().startsWith('+');

  let nsn = digits;
  if (digits.startsWith(country.callingCode)) {
    nsn = stripDuplicateCountryCode(digits, country);
  } else if (hadPlus && digits) {
    // Pasted a number for a different country: detect its calling code and
    // normalize against it instead of silently mis-validating.
    for (const c of SUPPORTED_COUNTRIES) {
      const rest = digits.slice(c.callingCode.length);
      if (digits.startsWith(c.callingCode) && new RegExp(c.nsnPattern).test(rest)) {
        return { nsn: rest, e164: `+${c.callingCode}${rest}`, isValid: true };
      }
    }
  }

  const isValid = new RegExp(country.nsnPattern).test(nsn);
  return { nsn, e164: `+${country.callingCode}${nsn}`, isValid };
}

/** Convenience: E.164 for `raw` under `country` (no validation). */
export function toE164(raw: string, country: CountryInfo): string {
  return normalizePhoneForCountry(raw, country).e164;
}
