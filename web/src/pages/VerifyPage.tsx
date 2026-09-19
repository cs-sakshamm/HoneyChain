import React, { useEffect, useState } from 'react';
import { ShieldCheck, AlertOctagon, RefreshCw, Hexagon, Search } from 'lucide-react';
import { fetchVerificationData, VerificationResponse } from '../api/honeychainApi';
import { ProductSummary } from '../components/ProductSummary';
import { ProvenanceTimeline } from '../components/ProvenanceTimeline';
import { BlockchainProof } from '../components/BlockchainProof';
import { IoTTelemetry } from '../components/IoTTelemetry';
import { AIAnalysis } from '../components/AIAnalysis';
import { LabReport } from '../components/LabReport';
import { PackagingInfo } from '../components/PackagingInfo';
import { QRDisplay } from '../components/QRDisplay';

interface Props {
  batchId: string;
}

export const VerifyPage: React.FC<Props> = ({ batchId }) => {
  const [data, setData] = useState<VerificationResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetchVerificationData(batchId);
      setData(res);
    } catch (err: any) {
      setError(err.message || 'Unable to reach HoneyChain verification service.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (batchId) {
      loadData();
    }
  }, [batchId]);

  return (
    <div className="app-wrapper">
      {/* Top Brand Bar */}
      <header
        style={{
          borderBottom: '1px solid var(--border-color)',
          backgroundColor: 'rgba(15, 23, 42, 0.8)',
          backdropFilter: 'blur(10px)',
          position: 'sticky',
          top: 0,
          zIndex: 50,
          padding: '12px 16px',
        }}
      >
        <div style={{ maxWidth: '760px', margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <div
              style={{
                width: '32px',
                height: '32px',
                borderRadius: '8px',
                background: 'linear-gradient(135deg, #F59E0B, #D97706)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#0F172A',
                fontWeight: 900,
              }}
            >
              <Hexagon size={20} fill="#0F172A" />
            </div>
            <div>
              <div style={{ fontFamily: 'var(--font-heading)', fontWeight: 800, fontSize: '17px', color: 'var(--text-primary)', letterSpacing: '-0.3px', lineHeight: 1.1 }}>
                HoneyChain
              </div>
              <div style={{ fontSize: '10px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.8px', fontWeight: 600 }}>
                Consumer Provenance
              </div>
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '11px', color: 'var(--success-green)', background: 'var(--success-green-bg)', padding: '4px 10px', borderRadius: '20px', border: '1px solid rgba(16, 185, 129, 0.3)' }}>
            <ShieldCheck size={14} />
            <span style={{ fontWeight: 700 }}>Official Verification</span>
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="main-container">
        {loading && (
          <div style={{ textAlign: 'center', padding: '60px 20px' }}>
            <RefreshCw size={36} color="var(--primary-gold)" className="spin-animation" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 16px' }} />
            <style>{`@keyframes spin { 100% { transform: rotate(360deg); } }`}</style>
            <h2 style={{ fontFamily: 'var(--font-heading)', fontSize: '20px', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '6px' }}>
              Verifying product...
            </h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>
              Connecting to HoneyChain cryptographic provenance protocol for batch {batchId}
            </p>
          </div>
        )}

        {!loading && error && (
          <div className="honey-card" style={{ textAlign: 'center', padding: '40px 20px', borderColor: 'rgba(239, 68, 68, 0.4)' }}>
            <div style={{ width: '48px', height: '48px', borderRadius: '50%', background: 'var(--danger-red-bg)', color: 'var(--danger-red)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
              <AlertOctagon size={28} />
            </div>
            <h2 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '8px' }}>
              Unable to reach HoneyChain verification service
            </h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginBottom: '20px' }}>
              {error}
            </p>
            <button onClick={loadData} className="btn-primary" style={{ margin: '0 auto' }}>
              <RefreshCw size={14} /> Retry Verification
            </button>
          </div>
        )}

        {!loading && !error && data && !data.found && (
          <div className="honey-card" style={{ textAlign: 'center', padding: '40px 20px', borderColor: 'rgba(239, 68, 68, 0.4)' }}>
            <div style={{ width: '56px', height: '56px', borderRadius: '50%', background: 'var(--danger-red-bg)', color: 'var(--danger-red)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
              <AlertOctagon size={32} />
            </div>
            <h2 style={{ fontFamily: 'var(--font-heading)', fontSize: '22px', fontWeight: 800, color: 'var(--danger-red)', marginBottom: '8px' }}>
              Verification record not found
            </h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '14px', maxWidth: '480px', margin: '0 auto 20px' }}>
              Batch code <span style={{ fontFamily: 'var(--font-mono)', color: 'var(--text-primary)', fontWeight: 700 }}>{batchId}</span> is not registered in the HoneyChain cryptographic provenance registry. Please check the batch code or contact the honey producer.
            </p>
            <div style={{ background: 'rgba(15, 23, 42, 0.6)', border: '1px solid var(--border-subtle)', borderRadius: '10px', padding: '12px', maxWidth: '360px', margin: '0 auto 20px', fontSize: '12px', color: 'var(--text-muted)' }}>
              Warning: Counterfeit protection alert. Only genuine packages with active HoneyChain blockchain certificates can be validated.
            </div>
          </div>
        )}

        {!loading && !error && data && data.found && (
          <>
            {/* 1. Product Summary & Authenticity Hero */}
            <ProductSummary
              product={data.product}
              harvester={data.harvester}
              status={data.status}
              isFullyVerified={data.isFullyVerified}
              batchId={batchId}
            />

            {/* 2. Blockchain Proof Section */}
            <BlockchainProof
              blockchain={data.blockchainVerification}
              batchId={batchId}
              provenanceEvents={data.provenanceEvents}
            />

            {/* 3. Provenance Timeline */}
            <ProvenanceTimeline
              harvester={data.harvester}
              processing={data.collectionProcessing}
              lab={data.labVerification}
              packaging={data.packaging}
              provenanceEvents={data.provenanceEvents}
            />

            {/* 4. Laboratory Verification */}
            <LabReport
              lab={data.labVerification}
              batchId={batchId}
            />

            {/* 5. Hive IoT Sensory Telemetry */}
            {data.iotTelemetry && (
              <IoTTelemetry telemetry={data.iotTelemetry} />
            )}

            {/* 6. AI Colony Health & Anomaly Evaluation */}
            {data.aiAnalysis && (
              <AIAnalysis ai={data.aiAnalysis} />
            )}

            {/* 7. Processing & Packaging */}
            <PackagingInfo
              packaging={data.packaging}
              processing={data.collectionProcessing}
              batchId={batchId}
            />

            {/* 6. Scannable QR Code */}
            <QRDisplay
              batchId={batchId}
            />
          </>
        )}
      </main>

      {/* Footer */}
      <footer style={{ borderTop: '1px solid var(--border-subtle)', padding: '24px 16px', textAlign: 'center', marginTop: 'auto', backgroundColor: 'var(--bg-main)' }}>
        <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '4px' }}>
          &copy; 2026 HoneyChain Cryptographic Traceability Protocol
        </div>
        <div style={{ fontSize: '11px', color: '#475569' }}>
          Powered by Smart Contracts, Hardware Edge IoT & NABL Certified Testing
        </div>
      </footer>
    </div>
  );
};
