import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/utils/phone_utils.dart';

void main() {
  group('normalizePhoneForCountry — India (+91, default)', () {
    const country = kDefaultCountry; // India

    test('10-digit local numbers normalize to +91 E.164', () {
      expect(normalizePhoneForCountry('9876543210', country).e164, '+919876543210');
      expect(normalizePhoneForCountry('98765 43210', country).e164, '+919876543210');
      expect(normalizePhoneForCountry('98765-43210', country).e164, '+919876543210');
    });

    test('validation follows Indian NSN rules (starts 6-9, 10 digits)', () {
      expect(normalizePhoneForCountry('9876543210', country).isValid, isTrue);
      expect(normalizePhoneForCountry('5876543210', country).isValid, isFalse);
      expect(normalizePhoneForCountry('987654321', country).isValid, isFalse);
    });

    test('leading zero trunk prefix is stripped', () {
      final n = normalizePhoneForCountry('09876543210', country);
      expect(n.e164, '+919876543210');
      expect(n.isValid, isTrue);
    });

    test('pasted +91 number does not duplicate the country code', () {
      final n = normalizePhoneForCountry('+91 98765 43210', country);
      expect(n.e164, '+919876543210');
      expect(n.nsn, '9876543210');
    });

    test('pasted 91-prefixed digits without plus are normalized once', () {
      expect(normalizePhoneForCountry('919876543210', country).e164, '+919876543210');
    });

    test('empty and junk input are invalid but still E.164-shaped', () {
      final n = normalizePhoneForCountry('', country);
      expect(n.isValid, isFalse);
      expect(n.e164, '+91');
    });
  });

  group('normalizePhoneForCountry — United States (+1)', () {
    final us = countryByIso('US');

    test('10-digit numbers normalize to +1 E.164', () {
      expect(normalizePhoneForCountry('(555) 123-4567', us).e164, '+15551234567');
      expect(normalizePhoneForCountry('555 123 4567', us).isValid, isTrue);
    });

    test('pasted +1 number is not duplicated', () {
      final n = normalizePhoneForCountry('+1 555 123 4567', us);
      expect(n.e164, '+15551234567');
      expect(n.nsn, '5551234567');
    });

    test('wrong length is invalid', () {
      expect(normalizePhoneForCountry('555123456', us).isValid, isFalse);
      expect(normalizePhoneForCountry('55512345678', us).isValid, isFalse);
    });
  });

  group('normalizePhoneForCountry — United Kingdom (+44)', () {
    final gb = countryByIso('GB');

    test('10-digit UK numbers normalize to +44 E.164', () {
      expect(normalizePhoneForCountry('7400 123456', gb).e164, '+447400123456');
      expect(normalizePhoneForCountry('07400 123456', gb).isValid, isTrue,
          reason: '0 trunk prefix stripped because remainder validates');
    });
  });

  group('normalizePhoneForCountry — United Arab Emirates (+971)', () {
    final ae = countryByIso('AE');

    test('8-9 digit numbers normalize to +971 E.164', () {
      expect(normalizePhoneForCountry('50 123 4567', ae).e164, '+971501234567');
      expect(normalizePhoneForCountry('50123456', ae).isValid, isTrue);
      expect(normalizePhoneForCountry('5012345', ae).isValid, isFalse);
    });

    test('0 trunk prefix is stripped when remainder validates', () {
      expect(normalizePhoneForCountry('050 123 4567', ae).e164, '+971501234567');
    });
  });

  group('country switching', () {
    test('dial code follows the selected country', () {
      expect(countryByIso('IN').dialCode, '+91');
      expect(countryByIso('US').dialCode, '+1');
      expect(countryByIso('GB').dialCode, '+44');
      expect(countryByIso('AE').dialCode, '+971');
      expect(countryByIso('SG').dialCode, '+65');
      expect(countryByIso('AU').dialCode, '+61');
    });

    test('same digits validate differently per country', () {
      // 10 digits: valid for IN/US/GB, not for 8-digit Singapore.
      const in_ = kDefaultCountry;
      final sg = countryByIso('SG');
      expect(normalizePhoneForCountry('9876543210', in_).isValid, isTrue);
      expect(normalizePhoneForCountry('9876543210', sg).isValid, isFalse);
      // Singapore numbers start 6/8/9 and are 8 digits.
      expect(normalizePhoneForCountry('81234567', sg).isValid, isTrue);
    });

    test('unknown ISO falls back to the default country (India)', () {
      expect(countryByIso('XX').isoCode, 'IN');
      expect(countryByIso(null).isoCode, 'IN');
      expect(countryByIso('').isoCode, 'IN');
    });

    test('country lookup by calling code', () {
      expect(countryByCallingCode('91')?.isoCode, 'IN');
      expect(countryByCallingCode('+44')?.isoCode, 'GB');
      expect(countryByCallingCode('999'), isNull);
    });

    test('pasted number from another country resolves to that country', () {
      // Indian country selected, US number pasted with a leading plus:
      // normalization must target +1, not mis-validate as a 10-digit Indian
      // number missing its trunk digits.
      const in_ = kDefaultCountry;
      final n = normalizePhoneForCountry('+15551234567', in_);
      expect(n.e164, '+15551234567');
      expect(n.isValid, isTrue);
    });
  });

  group('security invariants', () {
    test('E.164 output contains digits and a single leading plus only', () {
      for (final c in kSupportedCountries) {
        final n = normalizePhoneForCountry('123-45 (678) 90', c);
        expect(n.e164, matches(RegExp(r'^\+\d+$')), reason: c.isoCode);
      }
    });

    test('unsupported digit-count input never validates', () {
      const in_ = kDefaultCountry;
      expect(normalizePhoneForCountry('12345', in_).isValid, isFalse);
      expect(normalizePhoneForCountry('1234567890123456', in_).isValid, isFalse);
    });
  });
}
