import React, { useState, useEffect } from 'react';
import { VerifyPage } from './pages/VerifyPage';
import { QRDisplay } from './components/QRDisplay';
import { Search, Hexagon, ArrowRight } from 'lucide-react';

export const App: React.FC = () => {
  const [currentBatchId, setCurrentBatchId] = useState<string>('');
  const [inputBatchId, setInputBatchId] = useState<string>('HC-BATCH-2026-CA7715');

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

  if (currentBatchId) {
    return <VerifyPage batchId={currentBatchId} />;
  }

  // Fallback landing page if visited at root `/`
  return (
    <div className="app-wrapper" style={{ justifyContent: 'center', alignItems: 'center', padding: '24px' }}>
      <div style={{ maxWidth: '520px', width: '100%', textAlign: 'center' }}>
        <div
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
        </div>

        <h1 style={{ fontFamily: 'var(--font-heading)', fontSize: '28px', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '8px', letterSpacing: '-0.5px' }}>
          HoneyChain Verification
        </h1>
        <p style={{ color: 'var(--text-secondary)', fontSize: '14px', marginBottom: '28px' }}>
          Scan the QR on any HoneyChain authenticated jar, or enter a verified batch identifier below to inspect the complete cryptographic supply chain provenance.
        </p>

        <div className="honey-card" style={{ padding: '24px' }}>
          <form onSubmit={handleLookup}>
            <div style={{ textAlign: 'left', marginBottom: '8px', fontSize: '12px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-secondary)' }}>
              Batch / Package ID
            </div>
            <div style={{ display: 'flex', gap: '8px' }}>
              <input
                type="text"
                value={inputBatchId}
                onChange={(e) => setInputBatchId(e.target.value)}
                placeholder="e.g. HC-BATCH-2026-CA7715"
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
              <button type="submit" className="btn-primary" style={{ padding: '0 18px' }}>
                <Search size={16} /> Verify
              </button>
            </div>
          </form>

          <div style={{ marginTop: '20px', borderTop: '1px solid var(--border-subtle)', paddingTop: '16px', textAlign: 'left' }}>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px' }}>
              Quick Test Batches:
            </div>
            <button
              onClick={() => {
                window.history.pushState({}, '', '/verify/HC-BATCH-2026-CA7715');
                setCurrentBatchId('HC-BATCH-2026-CA7715');
              }}
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                width: '100%',
                padding: '10px 12px',
                borderRadius: '8px',
                background: 'rgba(245, 158, 11, 0.08)',
                border: '1px solid rgba(245, 158, 11, 0.25)',
                color: 'var(--primary-gold)',
                fontSize: '13px',
                fontWeight: 600,
                fontFamily: 'var(--font-mono)',
              }}
            >
              <span>HC-BATCH-2026-CA7715 (Certified Honey)</span>
              <ArrowRight size={14} />
            </button>
          </div>

          <div style={{ marginTop: '24px' }}>
            <QRDisplay batchId="HC-BATCH-2026-CA7715" />
          </div>
        </div>
      </div>
    </div>
  );
};
export default App;
