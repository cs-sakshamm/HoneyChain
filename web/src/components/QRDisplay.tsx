import React, { useState } from 'react';
import { QrCode, Copy, Check, Download } from 'lucide-react';

interface Props {
  batchId: string;
}

export const QRDisplay: React.FC<Props> = ({ batchId }) => {
  const [copied, setCopied] = useState(false);
  const [imageError, setImageError] = useState(false);
  const verifyUrl = `${window.location.origin}/verify/${encodeURIComponent(batchId)}`;
  const qrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${encodeURIComponent(verifyUrl)}&margin=10`;

  const handleCopy = () => {
    navigator.clipboard.writeText(verifyUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownload = () => {
    const a = document.createElement('a');
    a.href = qrImageUrl;
    a.download = `HoneyChain-QR-${batchId}.png`;
    a.target = '_blank';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  };

  return (
    <div className="honey-card" style={{ textAlign: 'center' }}>
      <div className="card-header-row" style={{ justifyContent: 'center', marginBottom: '8px' }}>
        <div className="card-title-group">
          <div className="card-title-icon">
            <QrCode size={20} />
          </div>
          <h2 className="card-title">Digital Package Verification QR</h2>
        </div>
      </div>
      <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginBottom: '16px' }}>
        This high-contrast QR code is printed directly on the product tamper-evident seal.
      </p>

      <div
        style={{
          display: 'inline-block',
          background: '#FFFFFF',
          padding: '14px',
          borderRadius: '16px',
          border: '1px solid var(--border-color)',
          boxShadow: '0 4px 15px rgba(0, 0, 0, 0.3)',
          marginBottom: '14px',
        }}
      >
        {!imageError ? (
          <img
            src={qrImageUrl}
            alt={`QR Code for batch ${batchId}`}
            width={180}
            height={180}
            style={{ display: 'block' }}
            onError={() => setImageError(true)}
          />
        ) : (
          <div
            style={{
              width: 180,
              height: 180,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              background: '#F8FAFC',
              borderRadius: '8px',
              padding: '12px',
              color: '#0F172A',
            }}
          >
            <QrCode size={64} color="#D97706" />
            <div style={{ fontSize: '12px', fontWeight: 700, marginTop: '8px', textAlign: 'center' }}>
              Digital Batch Tag
            </div>
            <div style={{ fontSize: '10px', color: '#64748B', textAlign: 'center', marginTop: '2px' }}>
              Cryptographically Verified
            </div>
          </div>
        )}
      </div>

      <div
        style={{
          fontFamily: 'var(--font-mono)',
          fontSize: '12px',
          color: 'var(--primary-gold)',
          background: 'rgba(15, 23, 42, 0.6)',
          padding: '8px 12px',
          borderRadius: '8px',
          wordBreak: 'break-all',
          marginBottom: '14px',
          border: '1px solid var(--border-subtle)',
        }}
      >
        {verifyUrl}
      </div>

      <div style={{ display: 'flex', gap: '10px', justifyContent: 'center' }}>
        <button onClick={handleCopy} className="btn-secondary">
          {copied ? <Check size={15} color="var(--success-green)" /> : <Copy size={15} />}
          {copied ? 'Copied to Clipboard' : 'Copy Verification Link'}
        </button>
        <button onClick={handleDownload} className="btn-secondary">
          <Download size={15} /> Download QR Code
        </button>
      </div>
    </div>
  );
};
