import React, { useState, useEffect } from 'react';
import { PublicVerification } from './pages/PublicVerification';

type ModalKey = 'Home' | 'About' | 'Traceability' | 'Technology' | 'Laboratory' | 'Contact' | null;

export const App: React.FC = () => {
  const [currentBatchId, setCurrentBatchId] = useState<string>('');
  const [inputBatchId, setInputBatchId] = useState<string>('');
  
  const [activeModal, setActiveModal] = useState<ModalKey>(null);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

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

  const navLinks: ModalKey[] = ['Home', 'About', 'Traceability', 'Technology', 'Laboratory', 'Contact'];

  const getModalContent = (key: ModalKey) => {
    switch(key) {
      case 'Home':
        return (
          <>
            <p>Welcome to the HoneyChain Public Verification Portal.</p>
            <p>This platform allows consumers to independently verify the origin, handling, and purity of their honey products by scanning a QR code that is securely linked to immutable records.</p>
          </>
        );
      case 'About':
        return (
          <>
            <p>HoneyChain was created to solve the pervasive problem of honey adulteration and the lack of transparency in traditional supply chains.</p>
            <p>By establishing an undeniable, cryptographically secure link between the apiary and the final packaged jar, our platform restores trust and ensures that you are consuming authentic honey.</p>
          </>
        );
      case 'Traceability':
        return (
          <>
            <p>Our traceability journey maps the complete lifecycle of the product:</p>
            <p className="modal-journey">Harvester &rarr; Hive &rarr; Collection &amp; Processing &rarr; Laboratory Test &rarr; Packaging &rarr; Verification</p>
            <p>Every single step is documented on an immutable ledger. By scanning the QR code, the complete history can be viewed instantly, guaranteeing end-to-end provenance.</p>
          </>
        );
      case 'Technology':
        return (
          <>
            <p>HoneyChain leverages a robust combination of enterprise technologies.</p>
            <p>IoT sensors monitor hive conditions in real-time, Artificial Intelligence flags anomalies, and a secure API ties everything to a scalable Blockchain smart contract database.</p>
            <p>This secure database-based traceability guarantees that historical data can never be silently altered.</p>
          </>
        );
      case 'Laboratory':
        return (
          <>
            <p>Independent laboratory testing is the cornerstone of HoneyChain's purity guarantee.</p>
            <p>The lab report, detailing precise test values for adulterants, moisture, and quality parameters, becomes a permanent part of the traceability record. This ensures scientific proof of quality is accessible directly to the consumer.</p>
          </>
        );
      case 'Contact':
        return (
          <>
            <p>For project inquiries, technical support, or partnership opportunities, please reach out to the HoneyChain Project Team.</p>
            <p className="modal-contact-info">
              <strong>Project Lead:</strong> Team DataMineX<br />
              <strong>System:</strong> HoneyChain Supply Node
            </p>
          </>
        );
      default:
        return null;
    }
  };

  return (
    <div className="app-layout">
      {/* Universal Simple Header */}
      <header className="app-header">
        <div className="header-logo-container" onClick={() => {
            window.history.pushState({}, '', `/`);
            setCurrentBatchId('');
          }} style={{cursor: 'pointer'}}>
          <span className="logo-text">HoneyChain</span>
        </div>
        
        {/* Desktop Nav */}
        <nav className="desktop-nav">
          {navLinks.map(link => (
            <button key={link} className="nav-link" onClick={() => setActiveModal(link)}>
              {link}
            </button>
          ))}
        </nav>

        <div className="header-actions">
          <button 
            className="theme-toggle" 
            onClick={() => setIsDark(!isDark)}
            aria-label="Toggle theme"
          >
            {isDark ? 'Light' : 'Dark'}
          </button>

          {/* Mobile Menu Button */}
          <button 
            className="mobile-menu-btn"
            onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
          >
            {isMobileMenuOpen ? 'Close' : 'Menu'}
          </button>
        </div>
      </header>

      {/* Mobile Nav Dropdown */}
      {isMobileMenuOpen && (
        <nav className="mobile-nav">
          {navLinks.map(link => (
            <button key={link} className="mobile-nav-link" onClick={() => {
              setActiveModal(link);
              setIsMobileMenuOpen(false);
            }}>
              {link}
            </button>
          ))}
        </nav>
      )}

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

      {/* Modal Overlay */}
      {activeModal && (
        <div className="modal-overlay" onClick={() => setActiveModal(null)}>
          <div className="modal-content" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2 className="modal-title">{activeModal}</h2>
              <button className="modal-close" onClick={() => setActiveModal(null)}>Close</button>
            </div>
            <div className="modal-body">
              {getModalContent(activeModal)}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
export default App;
