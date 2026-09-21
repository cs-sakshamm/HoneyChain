import React, { useEffect, useState } from 'react';
import { fetchVerificationData, VerificationResponse } from '../api/honeychainApi';
import { i18nDict } from '../i18n';

interface Props {
  batchId: string;
  language?: string;
}

export const PublicVerification: React.FC<Props> = ({ batchId, language = 'EN' }) => {
  const [data, setData] = useState<VerificationResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeStage, setActiveStage] = useState<string | null>(null);

  const t = (i18nDict[language] || i18nDict['EN']).pv;
  const isDemo = data?.batchId === 'HC-SIH-2026';

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetchVerificationData(batchId);
      setData(res);
    } catch (err: any) {
      setError("Verification temporarily unavailable");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (batchId) {
      loadData();
    }
  }, [batchId]);

  if (loading) {
    return (
      <div className="pv-message-container" style={{ textAlign: 'center', padding: '40px' }}>
        <div style={{ fontSize: '32px', marginBottom: '16px', animation: 'spin 2s linear infinite' }}>🐝</div>
        <p className="pv-message" style={{ fontWeight: 600 }}>Loading Verification Data...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="pv-message-container" style={{ textAlign: 'center', padding: '40px', background: 'rgba(239, 68, 68, 0.1)', borderRadius: '12px' }}>
        <p className="pv-message error-text" style={{ color: '#ef4444', fontWeight: 600, fontSize: '18px', marginBottom: '16px' }}>{error}</p>
        <button onClick={loadData} style={{ padding: '8px 16px', background: 'var(--text-primary)', color: 'var(--bg-color)', borderRadius: '6px', fontWeight: 600 }}>Retry</button>
      </div>
    );
  }

  if (data && !data.found) {
    return (
      <div className="pv-message-container" style={{ textAlign: 'center', padding: '40px' }}>
        <h2 className="pv-message-title" style={{ fontSize: '20px', fontWeight: 700 }}>{t.notFound}</h2>
        <p style={{ color: 'var(--text-secondary)', marginTop: '8px' }}>Please check the QR code or Batch ID.</p>
      </div>
    );
  }

  if (!data) return null;

  const hasHarvester = !!data.harvester && data.harvester.name !== 'No data available yet.';
  const hasHive = !!data.harvester && data.harvester.hiveCode !== 'No data available yet.';
  const hasCollection = !!data.collection && data.collection.center !== 'No data available yet.' || !!data.collectionProcessing;
  const hasProcessing = !!data.processing && data.processing.processor !== 'No data available yet.' || !!data.collectionProcessing;
  const hasLabTest = !!data.labVerification && data.labVerification.labName !== 'No data available yet.';
  const hasPackaging = !!data.packaging && data.packaging.facility !== 'No data available yet.';
  const hasBlockchain = !!data.blockchainVerification && data.blockchainVerification.onChainConfigured;

  const workflowNodes = [
    { id: 'harvester', title: '🐝 HARVESTER', active: hasHarvester },
    { id: 'collection', title: '📦 COLLECTION', active: hasCollection },
    { id: 'processing', title: '⚙️ PROCESSING', active: hasProcessing },
    { id: 'laboratory', title: '🧪 LAB TEST', active: hasLabTest },
    { id: 'packaging', title: '📦 PACKAGING', active: hasPackaging },
    { id: 'blockchain', title: '🔗 BLOCKCHAIN / INTEGRITY', active: hasBlockchain }
  ];

  const renderModalContent = () => {
    switch (activeStage) {
      case 'harvester':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Harvester Name</span><span className="pv-kv-value">{data.harvester.name}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Hive ID</span><span className="pv-kv-value">{data.harvester.hiveCode}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Location</span><span className="pv-kv-value">{data.harvester.apiaryLocation}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Bee Breed</span><span className="pv-kv-value">{data.harvester.beeBreed}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Queen Status</span><span className="pv-kv-value">{data.harvester.queenStatus}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Batch ID</span><span className="pv-kv-value">{data.batchId}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Status</span><span className="pv-kv-value">Harvest Completed</span></div>
          </div>
        );
      case 'collection':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Collection Center</span><span className="pv-kv-value">{data.collection?.center || data.collectionProcessing?.processor || 'N/A'}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Collector</span><span className="pv-kv-value">{data.collection?.collector || 'N/A'}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Received Date</span><span className="pv-kv-value">{data.collection?.receivedDate ? new Date(data.collection.receivedDate).toLocaleString() : 'N/A'}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Quantity Received</span><span className="pv-kv-value">{data.collection?.quantityKg || data.collectionProcessing?.quantityReceivedKg} kg</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Status</span><span className="pv-kv-value">{data.collection?.status || 'Received'}</span></div>
          </div>
        );
      case 'processing':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Processor</span><span className="pv-kv-value">{data.processing?.processor || data.collectionProcessing?.processor || 'N/A'}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Processing Date</span><span className="pv-kv-value">{(data.processing?.processingDate || data.collectionProcessing?.processingDate) ? new Date((data.processing?.processingDate || data.collectionProcessing?.processingDate)!).toLocaleString() : 'N/A'}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Method</span><span className="pv-kv-value">{data.processing?.method || data.collectionProcessing?.method || 'N/A'}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Input Quantity</span><span className="pv-kv-value">{data.processing?.inputQuantityKg || data.collectionProcessing?.inputQuantityKg || 'N/A'} kg</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Output Quantity</span><span className="pv-kv-value">{data.processing?.outputQuantityKg || data.collectionProcessing?.outputQuantityKg || 'N/A'} kg</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Status</span><span className="pv-kv-value">{data.processing?.status || 'Processed'}</span></div>
          </div>
        );
      case 'laboratory':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Laboratory</span><span className="pv-kv-value">{data.labVerification!.labName}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Report Number</span><span className="pv-kv-value">{data.labVerification!.reportId}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Batch ID</span><span className="pv-kv-value">{data.batchId}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Quality Score</span><span className="pv-kv-value">{data.labVerification!.qualityScore}/100</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Overall Result</span><span className="pv-kv-value" style={{fontWeight: 800, color: '#10b981'}}>{data.labVerification!.status}</span></div>
            
            <h4 style={{ margin: '24px 0 12px 0', fontSize: '14px', textTransform: 'uppercase', color: 'var(--text-secondary)', borderBottom: '1px solid var(--border-color)', paddingBottom: '8px' }}>Test Results Table</h4>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1px', background: 'var(--border-color)', border: '1px solid var(--border-color)', borderRadius: '8px', overflow: 'hidden' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 60px', background: 'var(--surface-color)', padding: '10px 12px', fontSize: '12px', fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase' }}>
                <div>Test</div>
                <div>Result</div>
                <div style={{textAlign: 'right'}}>Status</div>
              </div>
              {data.labVerification!.parameters.map((param, i) => (
                <div key={i} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 60px', background: 'var(--bg-color)', padding: '12px', fontSize: '13px', alignItems: 'center' }}>
                  <div style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{param.name}</div>
                  <div style={{ color: 'var(--text-secondary)' }}>{param.value}</div>
                  <div style={{ textAlign: 'right', fontWeight: 700, color: param.status === 'Pass' ? '#10b981' : '#ef4444' }}>{param.status}</div>
                </div>
              ))}
            </div>
            <div style={{ marginTop: '24px', textAlign: 'center' }}>
                <button style={{ background: 'var(--text-primary)', color: 'var(--bg-color)', padding: '10px 20px', borderRadius: '6px', fontWeight: 600, fontSize: '14px', cursor: 'pointer', border: 'none' }}>View Full Lab Report →</button>
            </div>
          </div>
        );
      case 'packaging':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Packaging Facility</span><span className="pv-kv-value">{data.packaging!.facility}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Packaging Date</span><span className="pv-kv-value">{new Date(data.packaging!.packagingDate).toLocaleString()}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Final Batch ID</span><span className="pv-kv-value">{data.batchId}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Net Quantity</span><span className="pv-kv-value">{data.packaging!.packageSize} x {data.packaging!.numberOfPackages}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Seal Status</span><span className="pv-kv-value">{data.packaging!.sealStatus}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">QR Generated At</span><span className="pv-kv-value">{new Date().toLocaleString()}</span></div>
          </div>
        );
      case 'blockchain':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Network</span><span className="pv-kv-value">{data.blockchainVerification!.network}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Contract</span><span className="pv-kv-value" style={{fontFamily: 'monospace', fontSize: '12px'}}>{data.blockchainVerification!.contractAddress}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Integrity Status</span><span className="pv-kv-value" style={{fontWeight: 700, color: '#10b981'}}>{data.blockchainVerification!.ledgerStatus}</span></div>
            {data.blockchainVerification!.latestTxHash && (
               <div className="pv-kv-row" style={{flexDirection: 'column', alignItems: 'flex-start', gap: '4px'}}>
                   <span className="pv-kv-label">Transaction Hash</span>
                   <span className="pv-kv-value" style={{fontFamily: 'monospace', fontSize: '11px', wordBreak: 'break-all', color: 'var(--text-secondary)'}}>{data.blockchainVerification!.latestTxHash}</span>
               </div>
            )}
            <div className="pv-kv-row"><span className="pv-kv-label">Total Validated Events</span><span className="pv-kv-value">{data.blockchainVerification!.totalConfirmedEvents}</span></div>
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="pv-container" style={{ maxWidth: '600px', margin: '0 auto', padding: '16px', fontFamily: 'Inter, sans-serif' }}>
      <div className="pv-header" style={{ textAlign: 'center', marginBottom: '32px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 800, margin: '0 0 4px 0', letterSpacing: '-0.5px' }}>HoneyChain</h1>
        <h2 style={{ fontSize: '15px', fontWeight: 600, color: 'var(--text-secondary)', margin: '0 0 24px 0', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Honey Traceability & Verification</h2>
        
        <div style={{ background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px', padding: '20px', textAlign: 'left', display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <h3 style={{ fontSize: '14px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-primary)', borderBottom: '1px solid var(--border-color)', paddingBottom: '8px', margin: '0' }}>Batch Summary</h3>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Batch ID</span><strong style={{ fontFamily: 'monospace' }}>{data.batchId}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Product</span><strong>{data.product?.productName || 'Raw Forest Honey'}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Total Quantity</span><strong>{data.product?.quantityKg || data.packaging?.packageSize}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Current Status</span><strong>{data.status}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Verification Status</span><strong style={{ color: data.isFullyVerified ? '#10b981' : '#f59e0b' }}>{data.isFullyVerified ? '✓ Verified' : 'Pending'}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Trace ID</span><strong style={{ fontFamily: 'monospace', fontSize: '12px' }}>{data.traceabilityId}</strong></div>
        </div>
      </div>

      <div style={{ marginBottom: '16px', fontSize: '14px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-secondary)' }}>Traceability Timeline</div>
      <div className="pv-workflow" style={{ display: 'flex', flexDirection: 'column', gap: '20px', position: 'relative' }}>
        {/* Timeline connector line */}
        <div style={{ position: 'absolute', left: '24px', top: '24px', bottom: '24px', width: '2px', background: 'var(--border-color)', zIndex: 0 }}></div>
        
        {workflowNodes.map((node) => (
          node.active && (
            <button 
              key={node.id} 
              onClick={() => setActiveStage(node.id)}
              style={{ 
                position: 'relative', zIndex: 1, display: 'flex', justifyContent: 'space-between', alignItems: 'center', 
                background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '9999px', 
                padding: '12px 24px', cursor: 'pointer', textAlign: 'left', width: '100%',
                boxShadow: '0 2px 8px rgba(0,0,0,0.05)', transition: 'all 0.2s ease'
              }}
              onMouseOver={(e) => { e.currentTarget.style.borderColor = 'var(--accent-color)'; e.currentTarget.style.transform = 'translateY(-1px)'; }}
              onMouseOut={(e) => { e.currentTarget.style.borderColor = 'var(--border-color)'; e.currentTarget.style.transform = 'translateY(0)'; }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <span style={{ fontSize: '15px', fontWeight: 700, color: 'var(--text-primary)' }}>{node.title}</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--text-primary)', background: 'var(--bg-color)', padding: '6px 14px', borderRadius: '9999px', border: '1px solid var(--border-color)' }}>
                <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px' }}>Tap to view</span>
                <span style={{ fontSize: '14px' }}>→</span>
              </div>
            </button>
          )
        ))}
        {data.isFullyVerified && (
             <div style={{ position: 'relative', zIndex: 1, display: 'flex', alignItems: 'center', gap: '12px', padding: '12px 24px', background: '#10b981', color: '#fff', borderRadius: '9999px', fontWeight: 700, boxShadow: '0 2px 8px rgba(16, 185, 129, 0.2)' }}>
                 <span style={{ fontSize: '18px' }}>✓</span> VERIFIED
             </div>
        )}
      </div>

      <div className="pv-footer" style={{ marginTop: '40px', background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px', padding: '24px' }}>
        <h2 className="pv-section-title" style={{ fontSize: '16px', fontWeight: 800, marginBottom: '16px', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
          Verification Summary
        </h2>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Batch</span><strong style={{fontFamily: 'monospace'}}>{data.batchId}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Status</span><strong style={{color: data.isFullyVerified ? '#10b981' : 'inherit'}}>{data.isFullyVerified ? '✓ Verified' : 'Pending'}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Traceability</span><strong>{data.isFullyVerified ? 'Complete' : 'Incomplete'}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Lab Report</span><strong>{hasLabTest ? 'Available' : 'Pending'}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Packaging</span><strong>{hasPackaging ? 'Completed' : 'Pending'}</strong></div>
        </div>
      </div>

      {activeStage && (
        <div className="modal-overlay" onClick={() => setActiveStage(null)} style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(4px)', zIndex: 100, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}>
          <div className="modal-content" onClick={e => e.stopPropagation()} style={{ background: 'var(--bg-color)', width: '100%', maxWidth: '600px', maxHeight: '90vh', borderTopLeftRadius: '24px', borderTopRightRadius: '24px', display: 'flex', flexDirection: 'column', overflow: 'hidden', animation: 'slideUp 0.3s ease-out' }}>
            <div className="modal-header" style={{ padding: '20px 24px', borderBottom: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'var(--surface-color)' }}>
              <button onClick={() => setActiveStage(null)} style={{ display: 'flex', alignItems: 'center', gap: '6px', background: 'var(--bg-color)', border: '1px solid var(--border-color)', borderRadius: '9999px', color: 'var(--text-primary)', fontWeight: 600, fontSize: '13px', cursor: 'pointer', padding: '6px 14px', transition: 'all 0.2s ease' }} onMouseOver={(e) => e.currentTarget.style.borderColor = 'var(--text-secondary)'} onMouseOut={(e) => e.currentTarget.style.borderColor = 'var(--border-color)'}>
                <span style={{ fontSize: '16px' }}>←</span> Back
              </button>
              <h2 className="modal-title" style={{ fontSize: '16px', fontWeight: 800, margin: 0, position: 'absolute', left: '50%', transform: 'translateX(-50%)' }}>
                {workflowNodes.find(n => n.id === activeStage)?.title.replace(/^[^\w\s]+/, '').trim()}
              </h2>
              <button onClick={() => setActiveStage(null)} aria-label="Close modal" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', width: '32px', height: '32px', background: 'var(--border-color)', border: 'none', borderRadius: '50%', color: 'var(--text-primary)', fontWeight: 800, fontSize: '16px', cursor: 'pointer' }}>
                ✕
              </button>
            </div>
            <div className="modal-body" style={{ padding: '24px', overflowY: 'auto' }}>
              {renderModalContent()}
            </div>
          </div>
        </div>
      )}
      <style>{`
        @keyframes slideUp {
            from { transform: translateY(100%); }
            to { transform: translateY(0); }
        }
        @keyframes spin {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
};
