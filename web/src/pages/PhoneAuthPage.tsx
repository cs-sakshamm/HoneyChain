import React, { useCallback, useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import {
  Hexagon,
  Phone,
  ShieldCheck,
  RefreshCw,
  Loader2,
  ChevronDown,
} from 'lucide-react';
import {
  ensureRecaptcha,
  sendOtp,
  confirmOtp,
  clearRecaptcha,
  resetRecaptcha,
  friendlyFirebaseError,
  normalizePhoneForCountry,
  RECAPTCHA_CONTAINER_ID,
} from '../auth/phoneAuth';
import {
  DEFAULT_COUNTRY,
  SUPPORTED_COUNTRIES,
  dialCode,
  type CountryInfo,
} from '../auth/phone';

interface PhoneAuthPageProps {
  onAuthenticated: (idToken: string) => void;
}

type Stage = 'phone' | 'otp';

export const PhoneAuthPage: React.FC<PhoneAuthPageProps> = ({ onAuthenticated }) => {
  const [stage, setStage] = useState<Stage>('phone');
  const [phone, setPhone] = useState('');
  const [country, setCountry] = useState<CountryInfo>(DEFAULT_COUNTRY);
  const [otp, setOtp] = useState<string[]>(Array(6).fill(''));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [countdown, setCountdown] = useState(0);
  const [countryOpen, setCountryOpen] = useState(false);

  const confirmationRef = useRef<import('firebase/auth').ConfirmationResult | null>(null);
  const otpRefs = useRef<Array<HTMLInputElement | null>>(Array(6).fill(null));
  const unmountedRef = useRef(false);
  const sendingRef = useRef(false);

  useEffect(() => {
    unmountedRef.current = false;
    // Render the reCAPTCHA widget as soon as the page mounts (once).
    ensureRecaptcha().catch((e) => setError(friendlyFirebaseError(e)));
    return () => {
      unmountedRef.current = true;
      clearRecaptcha();
    };
  }, []);

  useEffect(() => {
    if (countdown <= 0) return;
    const t = window.setInterval(() => {
      if (!unmountedRef.current) setCountdown((c) => c - 1);
    }, 1000);
    return () => window.clearInterval(t);
  }, [countdown]);

  // Close the country dropdown on outside click or Escape — previously it
  // stayed open until another selection was made, trapping keyboard users
  // and blocking clicks on the rest of the page.
  useEffect(() => {
    if (!countryOpen) return;
    const onPointerDown = (e: MouseEvent) => {
      if (!(e.target as Element | null)?.closest('[data-country-select]')) {
        setCountryOpen(false);
      }
    };
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setCountryOpen(false);
    };
    document.addEventListener('mousedown', onPointerDown);
    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('mousedown', onPointerDown);
      document.removeEventListener('keydown', onKeyDown);
    };
  }, [countryOpen]);

  const handleSendOtp = useCallback(async () => {
    // Re-entrancy guard: a double-tap on Send/Resend must not fire two
    // Firebase verification requests.
    if (sendingRef.current) return;
    const normalized = normalizePhoneForCountry(phone, country);
    if (!normalized.isValid) {
      setError(`Enter a valid mobile number for ${country.name}.`);
      return;
    }
    sendingRef.current = true;
    setBusy(true);
    setError(null);
    try {
      await ensureRecaptcha(); // resets the widget if a previous attempt consumed it
      confirmationRef.current = await sendOtp(phone, country);
      setStage('otp');
      setCountdown(60);
      setOtp(Array(6).fill(''));
      window.setTimeout(() => otpRefs.current[0]?.focus(), 50);
    } catch (e) {
      setError(friendlyFirebaseError(e));
      resetRecaptcha();
    } finally {
      sendingRef.current = false;
      if (!unmountedRef.current) setBusy(false);
    }
  }, [phone, country]);

  const handleVerify = useCallback(
    async (codeOverride?: string) => {
      const confirmation = confirmationRef.current;
      if (!confirmation) {
        setError('No active verification. Please request a new code.');
        setStage('phone');
        return;
      }
      const code = codeOverride ?? otp.join('');
      if (code.length !== 6) {
        setError('Enter the 6-digit code from the SMS.');
        return;
      }
      setBusy(true);
      setError(null);
      try {
        const idToken = await confirmOtp(confirmation, code);
        // The code is consumed here; it is never logged or stored.
        onAuthenticated(idToken);
      } catch (e) {
        setError(friendlyFirebaseError(e));
        resetRecaptcha();
        setOtp(Array(6).fill(''));
        otpRefs.current[0]?.focus();
      } finally {
        if (!unmountedRef.current) setBusy(false);
      }
    },
    [otp, onAuthenticated]
  );

  const handleOtpChange = (index: number, value: string) => {
    const digit = value.replace(/\D/g, '').slice(-1);
    const next = [...otp];
    next[index] = digit;
    setOtp(next);
    if (digit && index < 5) {
      otpRefs.current[index + 1]?.focus();
    }
    if (next.every((d) => d !== '') && !busy) {
      void handleVerify(next.join(''));
    }
  };

  const handleOtpKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Backspace' && !otp[index] && index > 0) {
      otpRefs.current[index - 1]?.focus();
    }
  };

  /** Resend stays on the OTP stage and reuses the same guard as first send. */
  const handleResend = () => {
    if (sendingRef.current) return;
    setOtp(Array(6).fill(''));
    void handleSendOtp();
  };

  const handleCountrySelect = (c: CountryInfo) => {
    setCountry(c);
    setCountryOpen(false);
  };

  const normalized = normalizePhoneForCountry(phone, country);

  const inputStyle: React.CSSProperties = {
    height: '44px',
    background: 'rgba(15, 23, 42, 0.8)',
    border: '1px solid var(--border-color)',
    borderRadius: '10px',
    color: 'var(--text-primary)',
    fontSize: '14px',
    fontFamily: 'var(--font-mono)',
    outline: 'none',
  };

  return (
    <div className="app-wrapper" style={{ justifyContent: 'center', alignItems: 'center', padding: '24px' }}>
      <div style={{ maxWidth: '440px', width: '100%', textAlign: 'center' }}>
        <motion.div
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ duration: 0.3 }}
          style={{
            width: '64px',
            height: '64px',
            borderRadius: '16px',
            background: 'linear-gradient(135deg, #F59E0B, #D97706)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 20px',
            boxShadow: '0 8px 24px rgba(245, 158, 11, 0.3)',
          }}
        >
          <Hexagon size={36} color="#0F172A" />
        </motion.div>

        <h1
          style={{
            fontFamily: 'var(--font-heading)',
            fontSize: '26px',
            fontWeight: 800,
            color: 'var(--text-primary)',
            marginBottom: '8px',
            letterSpacing: '-0.5px',
          }}
        >
          {stage === 'phone' ? 'Sign in to HoneyChain' : 'Enter verification code'}
        </h1>
        <p style={{ color: 'var(--text-secondary)', fontSize: '14px', marginBottom: '24px' }}>
          {stage === 'phone'
            ? 'Verify your mobile number to inspect tamper-evident supply chain provenance.'
            : `Sent to ${normalized.e164}. Never share this code.`}
        </p>

        {error && (
          <div
            role="alert"
            style={{
              background: 'rgba(239, 68, 68, 0.12)',
              border: '1px solid rgba(239, 68, 68, 0.4)',
              color: '#F87171',
              borderRadius: '10px',
              padding: '10px 14px',
              fontSize: '13px',
              fontWeight: 600,
              marginBottom: '16px',
              textAlign: 'left',
            }}
          >
            {error}
          </div>
        )}

        <motion.div className="honey-card" style={{ padding: '24px' }} layout>
          {stage === 'phone' ? (
            <form
              onSubmit={(e) => {
                e.preventDefault();
                void handleSendOtp();
              }}
            >
              <label
                htmlFor="phone-input"
                style={{
                  display: 'block',
                  textAlign: 'left',
                  marginBottom: '8px',
                  fontSize: '12px',
                  fontWeight: 700,
                  textTransform: 'uppercase',
                  color: 'var(--text-secondary)',
                }}
              >
                Mobile number
              </label>

              {/*
                One fused container for country selector + number field:
                identical height (44px), border, and vertical alignment on
                every breakpoint. The calling code lives in the selector — the
                user can never type or duplicate it inside the number.
              */}
              <div
                style={{
                  display: 'flex',
                  alignItems: 'stretch',
                  height: '44px',
                  border: '1px solid var(--border-color)',
                  borderRadius: '10px',
                  background: 'rgba(15, 23, 42, 0.8)',
                  overflow: 'hidden',
                }}
              >
                <div style={{ position: 'relative', flexShrink: 0 }} data-country-select>
                  <button
                    type="button"
                    aria-label="Select country"
                    aria-haspopup="listbox"
                    aria-expanded={countryOpen}
                    onClick={() => setCountryOpen((o) => !o)}
                    disabled={busy}
                    style={{
                      height: '100%',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '0 10px',
                      background: 'none',
                      border: 'none',
                      borderRight: '1px solid var(--border-color)',
                      color: 'var(--text-primary)',
                      fontWeight: 700,
                      fontFamily: 'var(--font-heading)',
                      fontSize: '14px',
                      cursor: 'pointer',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    <span role="img" aria-hidden style={{ fontSize: '16px' }}>
                      {country.flag}
                    </span>
                    <span>{dialCode(country)}</span>
                    <ChevronDown size={14} style={{ color: 'var(--text-secondary)' }} />
                  </button>

                  {countryOpen && (
                    <ul
                      role="listbox"
                      aria-label="Country calling codes"
                      data-country-select
                      style={{
                        position: 'absolute',
                        top: 'calc(100% + 6px)',
                        left: 0,
                        zIndex: 30,
                        margin: 0,
                        padding: '6px',
                        listStyle: 'none',
                        width: '260px',
                        maxWidth: '80vw',
                        background: 'var(--bg-card)',
                        border: '1px solid var(--border-color)',
                        borderRadius: '10px',
                        boxShadow: '0 12px 32px rgba(0, 0, 0, 0.45)',
                        textAlign: 'left',
                      }}
                    >
                      {SUPPORTED_COUNTRIES.map((c) => (
                        <li key={c.isoCode}>
                          <button
                            type="button"
                            role="option"
                            aria-selected={c.isoCode === country.isoCode}
                            onClick={() => handleCountrySelect(c)}
                            style={{
                              width: '100%',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '10px',
                              padding: '8px 10px',
                              background: c.isoCode === country.isoCode ? 'rgba(245, 158, 11, 0.12)' : 'none',
                              border: 'none',
                              borderRadius: '8px',
                              color: 'var(--text-primary)',
                              cursor: 'pointer',
                              fontSize: '13px',
                              textAlign: 'left',
                            }}
                          >
                            <span role="img" aria-hidden style={{ fontSize: '18px' }}>
                              {c.flag}
                            </span>
                            <span style={{ fontWeight: 700, flex: 1 }}>{c.name}</span>
                            <span style={{ color: 'var(--text-secondary)', fontFamily: 'var(--font-mono)' }}>
                              {c.isoCode} · {dialCode(c)}
                            </span>
                          </button>
                        </li>
                      ))}
                    </ul>
                  )}
                </div>

                <input
                  id="phone-input"
                  type="tel"
                  inputMode="numeric"
                  autoComplete="tel-national"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value.replace(/[^\d\s\-()]/g, ''))}
                  placeholder={country.nsnHint}
                  disabled={busy}
                  style={{
                    ...inputStyle,
                    flex: 1,
                    minWidth: 0,
                    border: 'none',
                    borderRadius: 0,
                    background: 'transparent',
                    padding: '12px 14px',
                  }}
                />
              </div>

              {/* Live E.164 preview — own line so the row never reflows. */}
              <div
                style={{
                  marginTop: '6px',
                  textAlign: 'right',
                  fontSize: '12px',
                  fontWeight: 600,
                  fontFamily: 'var(--font-mono)',
                  color: normalized.isValid ? 'var(--text-secondary)' : '#F87171',
                }}
              >
                {normalized.e164}
              </div>

              {/* Firebase reCAPTCHA renders inside this container */}
              <div id={RECAPTCHA_CONTAINER_ID} style={{ margin: '16px auto 4px', display: 'flex', justifyContent: 'center' }} />

              <motion.button
                type="submit"
                className="btn-primary"
                disabled={busy || !normalized.isValid}
                style={{
                  width: '100%',
                  marginTop: '12px',
                  padding: '12px 18px',
                  justifyContent: 'center',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  opacity: busy || !normalized.isValid ? 0.6 : 1,
                }}
              >
                {busy ? <Loader2 size={16} className="spin" /> : <ShieldCheck size={16} />}
                {busy ? 'Sending OTP…' : 'Send OTP'}
              </motion.button>
            </form>
          ) : (
            <div>
              <div style={{ display: 'flex', gap: '8px', justifyContent: 'center', marginBottom: '16px', flexWrap: 'wrap' }}>
                {otp.map((digit, i) => (
                  <input
                    key={i}
                    ref={(el) => {
                      otpRefs.current[i] = el;
                    }}
                    type="text"
                    inputMode="numeric"
                    maxLength={1}
                    value={digit}
                    disabled={busy}
                    aria-label={`OTP digit ${i + 1}`}
                    onChange={(e) => handleOtpChange(i, e.target.value)}
                    onKeyDown={(e) => handleOtpKeyDown(i, e)}
                    style={{
                      width: '44px',
                      height: '52px',
                      textAlign: 'center',
                      fontSize: '20px',
                      fontWeight: 800,
                      fontFamily: 'var(--font-heading)',
                      color: 'var(--text-primary)',
                      background: 'rgba(15, 23, 42, 0.8)',
                      border: '1px solid var(--border-color)',
                      borderRadius: '10px',
                      outline: 'none',
                    }}
                  />
                ))}
              </div>

              <motion.button
                type="button"
                className="btn-primary"
                disabled={busy || otp.join('').length !== 6}
                onClick={() => void handleVerify()}
                style={{
                  width: '100%',
                  padding: '12px 18px',
                  justifyContent: 'center',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  opacity: busy || otp.join('').length !== 6 ? 0.6 : 1,
                }}
              >
                {busy ? <Loader2 size={16} className="spin" /> : <ShieldCheck size={16} />}
                {busy ? 'Verifying…' : 'Verify & Continue'}
              </motion.button>

              <div style={{ marginTop: '14px', fontSize: '13px', color: 'var(--text-secondary)' }}>
                {countdown > 0 ? (
                  <span style={{ fontWeight: 600 }}>Resend code in {countdown}s</span>
                ) : (
                  <button
                    type="button"
                    onClick={handleResend}
                    disabled={busy}
                    style={{
                      background: 'none',
                      border: 'none',
                      color: '#F59E0B',
                      fontWeight: 700,
                      cursor: 'pointer',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '6px',
                      fontSize: '13px',
                    }}
                  >
                    <RefreshCw size={14} /> Resend OTP
                  </button>
                )}
              </div>
            </div>
          )}
        </motion.div>

        <p
          style={{
            marginTop: '20px',
            fontSize: '12px',
            color: 'var(--text-secondary)',
            opacity: 0.7,
            lineHeight: 1.5,
          }}
        >
          By continuing, you agree to HoneyChain's Terms of Service and Privacy Policy.
        </p>
      </div>
    </div>
  );
};

export default PhoneAuthPage;
