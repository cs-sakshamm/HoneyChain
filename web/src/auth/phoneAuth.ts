/**
 * Firebase Phone OTP service for the HoneyChain web verifier.
 *
 * Flow: normalize phone (per selected country) → render reCAPTCHA (once) →
 * signInWithPhoneNumber → ConfirmationResult → confirm(code) → Firebase user.
 *
 * - OTP codes are never logged or stored.
 * - The reCAPTCHA verifier is a module-level singleton: created once, reset
 *   (not recreated) after each attempt, and cleared on unmount by the page.
 * - Normalization/validation is delegated to the shared `phone.ts` utility
 *   (mirrors the Flutter `phone_utils.dart`).
 */
import {
  RecaptchaVerifier,
  signInWithPhoneNumber,
  type Auth,
  type ConfirmationResult,
  type RecaptchaVerifier as RecaptchaVerifierType,
} from 'firebase/auth';
import { getFirebaseAuth } from './firebase';
import {
  DEFAULT_COUNTRY,
  type CountryInfo,
  normalizePhoneForCountry,
} from './phone';

export const RECAPTCHA_CONTAINER_ID = 'recaptcha-container';

let recaptchaVerifier: RecaptchaVerifierType | null = null;
let recaptchaRendered = false;
let recaptchaWidgetId: number | null = null;

/** Re-exported so pages have one import site for phone helpers. */
export {
  DEFAULT_COUNTRY,
  SUPPORTED_COUNTRIES,
  countryByIso,
  dialCode,
  normalizePhoneForCountry,
  toE164,
} from './phone';
export type { CountryInfo } from './phone';

/**
 * Legacy convenience wrapper (India default). New code should call
 * `normalizePhoneForCountry(raw, country)` directly.
 */
export function normalizePhoneNumber(raw: string): string {
  return normalizePhoneForCountry(raw, DEFAULT_COUNTRY).e164;
}

/** Maps Firebase auth errors to clean, user-facing messages. */
export function friendlyFirebaseError(error: unknown): string {
  const code = (error as { code?: string })?.code ?? '';
  switch (code) {
    case 'auth/invalid-phone-number':
      return "That mobile number doesn't look right. Please check and try again.";
    case 'auth/invalid-verification-code':
      return 'The code you entered is incorrect. Please check the SMS and try again.';
    case 'auth/code-expired':
    case 'auth/session-expired':
      return 'This verification session has expired. Please request a new code.';
    case 'auth/too-many-requests':
    case 'auth/quota-exceeded':
      return 'Too many attempts. Please wait a moment before trying again.';
    case 'auth/network-request-failed':
      return 'Network error. Please check your internet connection and try again.';
    case 'auth/operation-not-allowed':
      return 'Phone sign-in is not enabled yet. Please contact support.';
    case 'auth/captcha-check-failed':
      return 'reCAPTCHA verification failed. Please complete the challenge and try again.';
    case 'auth/missing-verification-code':
      return 'Enter the 6-digit code from the SMS.';
    default:
      return (error as { message?: string })?.message ?? 'Authentication failed. Please try again.';
  }
}

/**
 * Renders the reCAPTCHA exactly once. Subsequent calls reset the existing
 * widget instead of creating a duplicate.
 */
export async function ensureRecaptcha(
  onSolved?: () => void,
  onExpired?: () => void
): Promise<void> {
  const auth: Auth = getFirebaseAuth();

  if (recaptchaVerifier && recaptchaRendered) {
    resetRecaptcha();
    return;
  }

  if (recaptchaVerifier) {
    clearRecaptcha();
  }

  recaptchaVerifier = new RecaptchaVerifier(auth, RECAPTCHA_CONTAINER_ID, {
    size: 'normal',
    callback: () => onSolved?.(),
    'expired-callback': () => onExpired?.(),
  });

  recaptchaWidgetId = await recaptchaVerifier.render();
  recaptchaRendered = true;
}

/** Firebase-supported reset for the current widget (no duplicate render). */
export function resetRecaptcha(): void {
  if (!recaptchaVerifier || !recaptchaRendered) return;
  try {
    if (typeof window !== 'undefined' && window.grecaptcha && recaptchaWidgetId !== null) {
      window.grecaptcha.reset(recaptchaWidgetId);
    } else {
      recaptchaVerifier.clear();
      recaptchaRendered = false;
    }
  } catch {
    recaptchaRendered = false;
  }
}

/** Fully removes the verifier (used on unmount / logout). */
export function clearRecaptcha(): void {
  try {
    recaptchaVerifier?.clear();
  } catch {
    // already cleared
  }
  recaptchaVerifier = null;
  recaptchaRendered = false;
  recaptchaWidgetId = null;
}

/**
 * Sends the SMS OTP. Returns Firebase's ConfirmationResult which the caller
 * keeps in memory (never persisted) for the confirm() step.
 */
export async function sendOtp(
  phoneRaw: string,
  country: CountryInfo = DEFAULT_COUNTRY
): Promise<ConfirmationResult> {
  const auth = getFirebaseAuth();
  const normalized = normalizePhoneForCountry(phoneRaw, country);
  if (!normalized.isValid) {
    throw Object.assign(
      new Error(`Enter a valid mobile number for ${country.name}.`),
      { code: 'auth/invalid-phone-number' }
    );
  }
  const verifier = recaptchaVerifier;
  if (!verifier) {
    throw new Error('reCAPTCHA is not ready yet. Please wait a moment and try again.');
  }
  return signInWithPhoneNumber(auth, normalized.e164, verifier);
}

/** Verifies the 6-digit code. The code is used in-memory only. */
export async function confirmOtp(
  confirmation: ConfirmationResult,
  code: string
): Promise<string> {
  const result = await confirmation.confirm(code);
  if (!result?.user) {
    throw new Error('Verification failed. Please try again.');
  }
  return result.user.getIdToken();
}
