/// Centralized country-code & phone-number utilities for HoneyChain.
///
/// Single source of truth for:
///  - the supported country list (flag, ISO code, name, calling code),
///  - E.164 normalization (+[cc][nsn]) per selected country,
///  - per-country validation of the national number,
///  - duplicate-country-code stripping when the user pastes a full number.
///
/// AuthController (mobile) and the web `phone.ts` mirror the same mapping and
/// rules — keep the two in sync when editing.
library;

/// One selectable country in the phone-input picker.
class CountryInfo {
  final String isoCode; // e.g. 'IN'
  final String name; // e.g. 'India'
  final String flag; // regional-indicator emoji, e.g. '🇮🇳'
  final String callingCode; // digits only, e.g. '91' (no '+')
  /// NSN validation pattern as a raw-string (passed to RegExp at runtime).
  /// Stored as String so CountryInfo instances can be compile-time constants.
  final String nsnPattern;
  final int nsnMinLength;
  final int nsnMaxLength;
  final String nsnHint; // example formatting shown as input hint

  const CountryInfo({
    required this.isoCode,
    required this.name,
    required this.flag,
    required this.callingCode,
    required this.nsnPattern,
    required this.nsnMinLength,
    required this.nsnMaxLength,
    required this.nsnHint,
  });

  /// Display string inside the selector: '+91'.
  String get dialCode => '+$callingCode';

  /// Full-width flag when rendering narrow country rows.
  String get label => '$flag $name ($isoCode)';

  /// Convenience getter: compiles the stored pattern into a RegExp.
  RegExp get nsnRegExp => RegExp(nsnPattern);
}

/// Supported countries. Keep sorted by name; India first as the project
/// default market.
const List<CountryInfo> kSupportedCountries = [
  CountryInfo(
    isoCode: 'IN',
    name: 'India',
    flag: '🇮🇳',
    callingCode: '91',
    nsnPattern: r'^[6-9]\d{9}$',
    nsnMinLength: 10,
    nsnMaxLength: 10,
    nsnHint: '98765 43210',
  ),
  CountryInfo(
    isoCode: 'US',
    name: 'United States',
    flag: '🇺🇸',
    callingCode: '1',
    nsnPattern: r'^\d{10}$',
    nsnMinLength: 10,
    nsnMaxLength: 10,
    nsnHint: '(555) 123-4567',
  ),
  CountryInfo(
    isoCode: 'GB',
    name: 'United Kingdom',
    flag: '🇬🇧',
    callingCode: '44',
    nsnPattern: r'^\d{10}$',
    nsnMinLength: 10,
    nsnMaxLength: 10,
    nsnHint: '7400 123456',
  ),
  CountryInfo(
    isoCode: 'AE',
    name: 'United Arab Emirates',
    flag: '🇦🇪',
    callingCode: '971',
    nsnPattern: r'^\d{8,9}$',
    nsnMinLength: 8,
    nsnMaxLength: 9,
    nsnHint: '50 123 4567',
  ),
  CountryInfo(
    isoCode: 'SG',
    name: 'Singapore',
    flag: '🇸🇬',
    callingCode: '65',
    nsnPattern: r'^[689]\d{7}$',
    nsnMinLength: 8,
    nsnMaxLength: 8,
    nsnHint: '8123 4567',
  ),
  CountryInfo(
    isoCode: 'AU',
    name: 'Australia',
    flag: '🇦🇺',
    callingCode: '61',
    nsnPattern: r'^\d{9}$',
    nsnMinLength: 9,
    nsnMaxLength: 9,
    nsnHint: '412 345 678',
  ),
];

/// Default selection when the user has not picked a country (project requires
/// India as the default market).
/// Defined directly (not as kSupportedCountries[0]) because list indexing is
/// not a compile-time constant expression in Dart.
const CountryInfo kDefaultCountry = CountryInfo(
  isoCode: 'IN',
  name: 'India',
  flag: '🇮🇳',
  callingCode: '91',
  nsnPattern: r'^[6-9]\d{9}$',
  nsnMinLength: 10,
  nsnMaxLength: 10,
  nsnHint: '98765 43210',
);

/// Resolves the country for an ISO code; falls back to the default.
CountryInfo countryByIso(String? iso) {
  final needle = (iso ?? '').trim().toUpperCase();
  for (final c in kSupportedCountries) {
    if (c.isoCode == needle) return c;
  }
  return kDefaultCountry;
}

/// Resolves the country for a calling code (digits only); falls back to null
/// when unknown so callers can decide.
CountryInfo? countryByCallingCode(String callingCode) {
  final needle = callingCode.replaceAll(RegExp(r'\D'), '');
  for (final c in kSupportedCountries) {
    if (c.callingCode == needle) return c;
  }
  return null;
}

/// Strips every separator users commonly type (spaces, dashes, brackets,
/// dots), returning the bare digit string.
String stripPhoneSeparators(String raw) {
  return raw.replaceAll(RegExp(r'[\s\-().]'), '');
}

/// Removes a duplicated country code from the national number, e.g. the user
/// pasted `+91 9876543210` while +91 is already selected. Returns the number
/// with exactly one copy of the country code removed — only when what remains
/// still validates for the country (so genuine numbers that begin with the
/// same digits are not mangled).
String stripDuplicateCountryCode(String digits, CountryInfo country) {
  final cc = country.callingCode;
  if (cc.isEmpty || !digits.startsWith(cc)) return digits;
  final remainder = digits.substring(cc.length);
  if (remainder.isEmpty) return digits;
  // Leading '0' trunk prefix (e.g. '09876543210') — drop it too.
  final trunkless =
      remainder.startsWith('0') ? remainder.substring(1) : remainder;
  final looksValid = country.nsnRegExp.hasMatch(trunkless);
  final remainderLooksValid = country.nsnRegExp.hasMatch(remainder);
  if (looksValid || remainderLooksValid) {
    return looksValid ? trunkless : remainder;
  }
  return digits;
}

/// Result of normalizing a phone number for the selected country.
class PhoneNormalization {
  /// The national (significant) number, digits only — what sits right of the
  /// calling code.
  final String nsn;

  /// Full E.164 string: +[countryCallingCode][nsn].
  final String e164;

  /// True when [nsn] matches the country's expected format.
  final bool isValid;

  const PhoneNormalization({
    required this.nsn,
    required this.e164,
    required this.isValid,
  });
}

/// Normalizes raw user input against [country] and validates it.
///
/// Handles: separators, a leading '+', a duplicated country code, and trunk
/// prefixes. The returned [PhoneNormalization.e164] is always the value to
/// send to Firebase / the backend.
PhoneNormalization normalizePhoneForCountry(String raw, CountryInfo country) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');

  // A leading '+' means the user typed/pasted a full international number.
  final hadPlus = raw.trim().startsWith('+');

  if (digits.startsWith(country.callingCode)) {
    digits = stripDuplicateCountryCode(digits, country);
  } else if (hadPlus && digits.isNotEmpty) {
    // Pasted a number for a different country: try to detect its calling code
    // and normalize to it instead of silently mis-validating.
    for (final c in kSupportedCountries) {
      if (c.callingCode.isNotEmpty &&
          digits.startsWith(c.callingCode) &&
          c.nsnRegExp.hasMatch(digits.substring(c.callingCode.length))) {
        final nsn = digits.substring(c.callingCode.length);
        return PhoneNormalization(
          nsn: nsn,
          e164: '+${c.callingCode}$nsn',
          isValid: true,
        );
      }
    }
  }

  // Strip a leading trunk prefix '0' (e.g. local dialling convention).
  // Only strip when what remains is a valid national number for the country.
  if (digits.startsWith('0')) {
    final trunkless = digits.substring(1);
    if (country.nsnRegExp.hasMatch(trunkless)) {
      digits = trunkless;
    }
  }

  final isValid = country.nsnRegExp.hasMatch(digits);
  return PhoneNormalization(
    nsn: digits,
    e164: '+${country.callingCode}$digits',
    isValid: isValid,
  );
}

/// Convenience: E.164 for [raw] under [country] (no validation).
String toE164(String raw, CountryInfo country) =>
    normalizePhoneForCountry(raw, country).e164;
