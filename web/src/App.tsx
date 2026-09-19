import React, { useState, useEffect } from 'react';
import { VerifyPage } from './pages/VerifyPage';
import { Search, Hexagon } from 'lucide-react';
import { motion, AnimatePresence, useReducedMotion } from 'framer-motion';
import { getPageVariants, getButtonProps } from './utils/animations';

export const App: React.FC = () => {
  const [currentBatchId, setCurrentBatchId] = useState<string>('');
  const [inputBatchId, setInputBatchId] = useState<string>('');
  const shouldReduceMotion = useReducedMotion();

  useEffect(() => {
    const parseUrl = () => {
      const path = window.location.pathname;
      const match = path.match(/\/verify\/([^/?#]+)/i);
      if (match && match[1]) {
        setCurrentBatchId(decodeURIComponent(match[1]));
        return;
      }

      const params = new URLSearchParams(window.location.search);
      const batchParam = params.get('batch') || params.get('batchId') || params.get('id');
      if (batchParam) {
        setCurrentBatchId(batchParam);
        return;
      }

      // If at root and no param, default empty
      setCurrentBatchId('');
    };

    parseUrl();
    window.addEventListener('popstate', parseUrl);
    return () => window.removeEventListener('popstate', parseUrl);
  }, []);

  const handleLookup = (e: React.FormEvent) => {
    e.preventDefault();
    if (!inputBatchId.trim()) return;
    const cleanId = inputBatchId.trim();
    window.history.pushState({}, '', `/verify/${encodeURIComponent(cleanId)}`);
    setCurrentBatchId(cleanId);
  };

  return (
    <AnimatePresence mode="wait">
      {currentBatchId ? (
        <motion.div
          key="verify-page"
          initial="hidden"
          animate="visible"
          exit="exit"
          variants={getPageVariants(shouldReduceMotion ?? false)}
          style={{ width: '100%', height: '100%' }}
        >
          <VerifyPage batchId={currentBatchId} />
        </motion.div>
      ) : (
        <motion.div
          key="landing-page"
          initial="hidden"
          animate="visible"
          exit="exit"
          variants={getPageVariants(shouldReduceMotion ?? false)}
          className="app-wrapper"
          style={{ justifyContent: 'center', alignItems: 'center', padding: '24px' }}
        >
          <div style={{ maxWidth: '520px', width: '100%', textAlign: 'center' }}>
            <motion.div
              initial={{ scale: shouldReduceMotion ? 1 : 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ delay: 0.1, duration: 0.3 }}
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

            <motion.h1
              initial={{ opacity: 0, y: shouldReduceMotion ? 0 : 5 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.15, duration: 0.3 }}
              style={{ fontFamily: 'var(--font-heading)', fontSize: '28px', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '8px', letterSpacing: '-0.5px' }}
            >
              HoneyChain Verification
            </motion.h1>
            <motion.p
              initial={{ opacity: 0, y: shouldReduceMotion ? 0 : 5 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2, duration: 0.3 }}
              style={{ color: 'var(--text-secondary)', fontSize: '14px', marginBottom: '28px' }}
            >
              Scan the QR on a HoneyChain package, or enter a batch identifier below to inspect the tamper-evident supply chain provenance.
            </motion.p>

            <motion.div
              initial={{ opacity: 0, y: shouldReduceMotion ? 0 : 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.25, duration: 0.3 }}
              className="honey-card" style={{ padding: '24px' }}
            >
              <form onSubmit={handleLookup}>
                <div style={{ textAlign: 'left', marginBottom: '8px', fontSize: '12px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-secondary)' }}>
                  Batch / Package ID
                </div>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <input
                    type="text"
                    value={inputBatchId}
                    onChange={(e) => setInputBatchId(e.target.value)}
                    placeholder="e.g. HNY-2026-0001"
                    style={{
                      flex: 1,
                      background: 'rgba(15, 23, 42, 0.8)',
                      border: '1px solid var(--border-color)',
                      borderRadius: '10px',
                      padding: '12px 14px',
                      color: 'var(--text-primary)',
                      fontSize: '14px',
                      fontFamily: 'var(--font-mono)',
                      outline: 'none',
                    }}
                  />
                  <motion.button
                    {...getButtonProps(shouldReduceMotion ?? false)}
                    type="submit"
                    className="btn-primary"
                    style={{ padding: '0 18px' }}
                  >
                    <Search size={16} /> Verify
                  </motion.button>
                </div>
              </form>
            </motion.div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};
export default App;
