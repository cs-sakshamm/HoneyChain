import React, { useState, useEffect } from 'react';
import { PublicVerification } from './pages/PublicVerification';
import { languages, i18nDict } from './i18n';

type ModalKey = 'About' | 'Traceability' | 'Technology' | 'Laboratory' | 'Contact' | null;

const HoneyChainLogo = ({ size = 28, showWordmark = true, text = "HoneyChain" }) => {
  return (
    <div style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }} onClick={() => {
      window.history.pushState({}, '', `/`);
      window.dispatchEvent(new Event('popstate'));
    }}>
      <svg width={size} height={size} viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M50 4.33L89.67 27.24L89.67 73.06L50 95.97L10.33 73.06L10.33 27.24Z" stroke="var(--accent-color)" strokeWidth="8" strokeLinecap="round" strokeLinejoin="round"/>
        <rect x="30" y="38" width="12" height="24" rx="6" fill="var(--accent-color)" />
        <rect x="58" y="38" width="12" height="24" rx="6" fill="var(--accent-color)" />
        <rect x="36" y="46" width="28" height="8" rx="4" fill="var(--text-primary)" />
      </svg>
      {showWordmark && (
        <span style={{ 
          fontFamily: "'Share Tech', sans-serif", 
          fontSize: size >= 26 ? 22 : size * 0.75, 
          fontWeight: 600, 
          color: 'var(--text-primary)', 
          marginLeft: size * 0.32,
          letterSpacing: 0.5,
          lineHeight: 1
        }}>
          {text}
        </span>
      )}
    </div>
  );
};

export const App: React.FC = () => {
  const [currentBatchId, setCurrentBatchId] = useState<string>('');
  const [inputBatchId, setInputBatchId] = useState<string>('');
  const [activeModal, setActiveModal] = useState<ModalKey>(null);
  const [language, setLanguage] = useState<string>('EN');
  const [showLangMenu, setShowLangMenu] = useState(false);
  
  const t = i18nDict[language] || i18nDict['EN'];

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

  const footerLinks: ModalKey[] = ['About', 'Traceability', 'Technology', 'Laboratory', 'Contact'];

  const getModalContent = (key: ModalKey) => {
    switch(key) {
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
    <div className="app-layout" onClick={() => setShowLangMenu(false)}>
      
      {/* Top Header - Actions Only */}
      <header className="app-header-centered" style={{ justifyContent: 'space-between', padding: '16px 24px', width: '100%', boxSizing: 'border-box' }}>
        
        {/* Left Actions - Language Selector */}
        <div className="header-left-actions" style={{ display: 'flex', alignItems: 'center' }}>
          <div className="language-selector-wrapper" onClick={e => e.stopPropagation()}>
            <button className="icon-toggle-btn language-btn" onClick={() => setShowLangMenu(!showLangMenu)}>
              <svg xmlns="http://www.w3.org/2000/svg" height="18" width="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zm6.93 6h-2.95c-.32-1.25-.78-2.45-1.38-3.56 1.84.63 3.37 1.91 4.33 3.56zM12 4.04c.83 1.2 1.48 2.53 1.91 3.96h-3.82c.43-1.43 1.08-2.76 1.91-3.96zM4.26 14C4.09 13.36 4 12.69 4 12s.09-1.36.26-2h3.38c-.08.66-.14 1.32-.14 2 0 .68.06 1.34.14 2H4.26zm.81 2h2.95c.32 1.25.78 2.45 1.38 3.56-1.84-.63-3.37-1.9-4.33-3.56zm2.95-8H5.07c.96-1.66 2.49-2.93 4.33-3.56C8.81 5.55 8.35 6.75 8.02 8zM12 19.96c-.83-1.2-1.48-2.53-1.91-3.96h3.82c-.43 1.43-1.08 2.76-1.91 3.96zM14.34 14H9.66c-.09-.66-.16-1.32-.16-2 0-.68.07-1.35.16-2h4.68c.09.65.16 1.32.16 2 0 .68-.07 1.34-.16 2zm1.25 5.56c.6-1.11 1.06-2.31 1.38-3.56h2.95c-.96 1.65-2.49 2.93-4.33 3.56zM16.36 14c.08-.66.14-1.32.14-2 0-.68-.06-1.34-.14-2h3.38c.17.64.26 1.31.26 2s-.09 1.36-.26 2h-3.38z"/>
              </svg>
              <span style={{ fontSize: '14px', fontWeight: 600, marginLeft: '6px' }}>{language}</span>
            </button>
            
            {showLangMenu && (
              <div className="language-dropdown" style={{ maxHeight: '300px', overflowY: 'auto', left: 0, right: 'auto' }}>
                {languages.map(lang => (
                  <button key={lang.code} onClick={() => { setLanguage(lang.code); setShowLangMenu(false); }}>
                    {lang.name}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Right Actions - Theme Toggle */}
        <div className="header-right-actions" style={{ display: 'flex', alignItems: 'center' }}>
          
          {/* Theme Toggle Button */}
          <button className="icon-toggle-btn" onClick={() => setIsDark(!isDark)} aria-label="Toggle theme">
            {isDark ? (
              // Light Mode Icon (Sun)
              <svg xmlns="http://www.w3.org/2000/svg" height="20" width="20" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 7c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zM2 13h2c.55 0 1-.45 1-1s-.45-1-1-1H2c-.55 0-1 .45-1 1s.45 1 1 1zm18 0h2c.55 0 1-.45 1-1s-.45-1-1-1h-2c-.55 0-1 .45-1 1s.45 1 1 1zM11 2v2c0 .55.45 1 1 1s1-.45 1-1V2c0-.55-.45-1-1-1s-1 .45-1 1zm0 18v2c0 .55.45 1 1 1s1-.45 1-1v-2c0-.55-.45-1-1-1s-1 .45-1 1zM5.99 4.58c-.39-.39-1.03-.39-1.41 0-.39.39-.39 1.03 0 1.41l1.06 1.06c.39.39 1.03.39 1.41 0 .39-.39.39-1.03 0-1.41L5.99 4.58zm12.37 12.37c-.39-.39-1.03-.39-1.41 0-.39.39-.39 1.03 0 1.41l1.06 1.06c.39.39 1.03.39 1.41 0 .39-.39.39-1.03 0-1.41l-1.06-1.06zm1.06-10.96c.39-.39.39-1.03 0-1.41-.39-.39-1.03-.39-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41.39.39 1.03.39 1.41 0l1.06-1.06zM7.05 18.36c.39-.39.39-1.03 0-1.41-.39-.39-1.03-.39-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41.39.39 1.03.39 1.41 0l1.06-1.06z"/>
              </svg>
            ) : (
              // Dark Mode Icon (Moon)
              <svg xmlns="http://www.w3.org/2000/svg" height="20" width="20" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 3c-4.97 0-9 4.03-9 9s4.03 9 9 9 9-4.03 9-9c0-.46-.04-.92-.1-1.36-.98 1.37-2.58 2.26-4.4 2.26-2.98 0-5.4-2.42-5.4-5.4 0-1.81.89-3.42 2.26-4.4-.44-.06-.9-.1-1.36-.1z"/>
              </svg>
            )}
          </button>
        </div>
      </header>

      <main className="app-main">
        {/* Centered Logo in the middle of the screen */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: '32px', textAlign: 'center' }}>
          <HoneyChainLogo size={42} showWordmark={true} text={t.logoText} />
          {!currentBatchId && (
            <div style={{ marginTop: '24px' }}>
              <h2 style={{ fontSize: '20px', fontWeight: 800, color: 'var(--text-primary)', fontFamily: "'Manrope', sans-serif" }}>
                {t.greeting}
              </h2>
              <p style={{ fontSize: '15px', color: 'var(--text-secondary)', marginTop: '8px', maxWidth: '420px', lineHeight: 1.5 }}>
                {t.aboutIntro}
              </p>
            </div>
          )}
        </div>
        {currentBatchId ? (
          <PublicVerification batchId={currentBatchId} language={language} />
        ) : (
          <div className="landing-container">
            <h1 className="landing-title">{t.verifyOrigin}</h1>
            <p className="landing-subtitle">
              {t.enterBatch}
            </p>

            <form onSubmit={handleLookup} className="lookup-form">
              <label htmlFor="batchId">{t.batchIdLabel}</label>
              <div className="lookup-input-group">
                <input
                  id="batchId"
                  type="text"
                  value={inputBatchId}
                  onChange={(e) => setInputBatchId(e.target.value)}
                  placeholder="HC-001"
                />
                <button type="submit" className="btn-primary">
                  {t.verifyBtn}
                </button>
              </div>
            </form>
          </div>
        )}
      </main>

      <footer className="simple-footer">
        <div className="footer-nav">
          {footerLinks.map(link => (
            <button key={link} className="footer-nav-link" onClick={() => setActiveModal(link)}>
              {t.nav[link as string] || link}
            </button>
          ))}
        </div>
        <p className="footer-copy">&copy; {new Date().getFullYear()} {t.footerCopy}</p>
      </footer>

      {/* Modal Overlay for Footer Links */}
      {activeModal && (
        <div className="modal-overlay" onClick={() => setActiveModal(null)}>
          <div className="modal-content" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2 className="modal-title">{t.nav[activeModal as string] || activeModal}</h2>
              <button className="modal-close" onClick={() => setActiveModal(null)}>{t.close}</button>
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
