import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/authentication/auth_controller.dart';

void main() {
  group('Phone OTP normalization (§9)', () {
    test('Normalizes 10-digit Indian local numbers to +91 E.164', () {
      expect(AuthController.normalizePhoneNumber('9876543210'), '+919876543210');
      expect(AuthController.normalizePhoneNumber('98765 43210'), '+919876543210');
      expect(AuthController.normalizePhoneNumber('98765-43210'), '+919876543210');
    });

    test('Keeps numbers that already carry a country code', () {
      expect(AuthController.normalizePhoneNumber('+919876543210'), '+919876543210');
      expect(AuthController.normalizePhoneNumber('+1 555 123 4567'), '+15551234567');
    });

    test('Handles leading-zero and 91-prefixed variants', () {
      expect(AuthController.normalizePhoneNumber('09876543210'), '+919876543210');
      expect(AuthController.normalizePhoneNumber('919876543210'), '+919876543210');
    });
  });
}
