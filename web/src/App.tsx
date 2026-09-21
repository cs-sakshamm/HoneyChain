import React, { useState, useEffect } from 'react';
import { PublicVerification } from './pages/PublicVerification';

export const App: React.FC = () => {
  const [currentBatchId, setCurrentBatchId] = useState<string>('');
  const [inputBatchId, setInputBatchId] = useState<string>('');
  
  // Theme Management
  const [isDark, setIsDark] = useState<boolean>(() => {
    const saved = localStorage.getItem('hc_theme');
    if (saved) return saved === 'dark';
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  });

  useEffect(() => {
    localStorage.setItem('hc_theme', isDark ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
  }, [isDark]);

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
    <div className="app-layout">
      <header className="app-header">
        <div className="header-logo-container" onClick={() => {
            window.history.pushState({}, '', `/`);
            setCurrentBatchId('');
          }} style={{cursor: 'pointer'}}>
          <span className="logo-text">HoneyChain</span>
        </div>

        <div className="header-actions">
          <button 
            className="theme-toggle" 
            onClick={() => setIsDark(!isDark)}
            aria-label="Toggle theme"
          >
            {isDark ? 'Light' : 'Dark'} Mode
          </button>
        </div>
      </header>

      <main className="app-main">
        {currentBatchId ? (
          <PublicVerification batchId={currentBatchId} />
        ) : (
          <div className="landing-container">
            <h1 className="landing-title">Honey Traceability & Verification</h1>
            <p className="landing-subtitle">
              Enter a batch identifier below to inspect the tamper-evident supply chain provenance.
            </p>

            <form onSubmit={handleLookup} className="lookup-form">
              <label htmlFor="batchId">Batch / Package ID</label>
              <div className="lookup-input-group">
                <input
                  id="batchId"
                  type="text"
                  value={inputBatchId}
                  onChange={(e) => setInputBatchId(e.target.value)}
                  placeholder="e.g. HC-001"
                />
                <button type="submit" className="btn-primary">
                  VERIFY
                </button>
              </div>
            </form>
          </div>
        )}
      </main>

      <footer className="app-footer">
        <div className="footer-left">
          <span className="footer-tag">Secured by Polygon Ledger</span>
        </div>
        <div className="footer-center">
          <span className="footer-text">Developed and Designed by</span> 
          <span className="footer-signature">Team DataMineX</span>
        </div>
        <div className="footer-right">
          <span className="footer-tag">Immutable Provenance</span>
        </div>
      </footer>
    </div>
  );
};
export default App;
