import React, { useEffect, useState } from 'react';
import { fetchVerificationData, VerificationResponse } from '../api/honeychainApi';
import { i18nDict } from '../i18n';
import { FiArrowLeft, FiChevronRight, FiX, FiCheckCircle, FiFileText, FiAward, FiShield } from 'react-icons/fi';

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
      <div className="pv-message-container" style={{ textAlign: 'center', padding: '40px', background: 'rgba(239, 68, 68, 0.1)', borderRadius: '16px' }}>
        <p className="pv-message error-text" style={{ color: '#ef4444', fontWeight: 600, fontSize: '18px', marginBottom: '16px' }}>{error}</p>
        <button onClick={loadData} style={{ padding: '8px 16px', background: 'var(--text-primary)', color: 'var(--bg-color)', borderRadius: '8px', fontWeight: 600, border: 'none', cursor: 'pointer' }}>Retry</button>
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
    { id: 'harvester', title: '01 Harvester', active: hasHarvester },
    { id: 'hive', title: '02 Hive', active: hasHive },
    { id: 'collection_processing', title: '03 Collection & Processing', active: hasCollection || hasProcessing },
    { id: 'laboratory', title: '04 Laboratory Test', active: hasLabTest },
    { id: 'lab_report', title: '05 Lab Report', active: hasLabTest },
    { id: 'packaging', title: '06 Packaging', active: hasPackaging },
    { id: 'blockchain', title: '07 Blockchain / Integrity', active: hasBlockchain }
  ];

  const formatDate = (dateStr?: string | null) => {
    if (!dateStr || dateStr === 'No data available yet.') return 'N/A';
    try {
      const d = new Date(dateStr);
      return isNaN(d.getTime()) ? dateStr : d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
    } catch {
      return dateStr;
    }
  };

  const renderModalContent = () => {
    switch (activeStage) {
      case 'harvester':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Harvester Name</span><span className="pv-kv-value">{data.harvester.name}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Beekeeper ID</span><span className="pv-kv-value">{data.harvester.beekeeperId}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Location</span><span className="pv-kv-value">{data.harvester.apiaryLocation}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Hive Code</span><span className="pv-kv-value">{data.harvester.hiveCode}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Bee Breed</span><span className="pv-kv-value">{data.harvester.beeBreed}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Queen Status</span><span className="pv-kv-value">{data.harvester.queenStatus}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Batch ID</span><span className="pv-kv-value">{data.batchId}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Status</span><span className="pv-kv-value">Harvest Completed</span></div>
          </div>
        );
      case 'hive':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Hive ID / Code</span><span className="pv-kv-value">{data.harvester.hiveCode}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Apiary Location</span><span className="pv-kv-value">{data.harvester.apiaryLocation}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Bee Breed</span><span className="pv-kv-value">{data.harvester.beeBreed}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Queen Status</span><span className="pv-kv-value">{data.harvester.queenStatus}</span></div>
            {data.iotTelemetry && (
              <>
                <h4 style={{ margin: '20px 0 10px 0', fontSize: '13px', textTransform: 'uppercase', color: 'var(--text-secondary)', borderBottom: '1px solid var(--border-color)', paddingBottom: '6px' }}>Telemetry Snapshot</h4>
                <div className="pv-kv-row"><span className="pv-kv-label">Temperature</span><span className="pv-kv-value">{data.iotTelemetry.temperature}</span></div>
                <div className="pv-kv-row"><span className="pv-kv-label">Humidity</span><span className="pv-kv-value">{data.iotTelemetry.humidity}</span></div>
                <div className="pv-kv-row"><span className="pv-kv-label">Weight</span><span className="pv-kv-value">{data.iotTelemetry.weight}</span></div>
                <div className="pv-kv-row"><span className="pv-kv-label">Acoustics</span><span className="pv-kv-value">{data.iotTelemetry.acoustics}</span></div>
              </>
            )}
          </div>
        );
      case 'collection_processing':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Collection Center</span><span className="pv-kv-value">{data.collection?.center || data.collectionProcessing?.processor || 'N/A'}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Collector</span><span className="pv-kv-value">{data.collection?.collector || 'N/A'}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Received Date</span><span className="pv-kv-value">{data.collection?.receivedDate ? new Date(data.collection.receivedDate).toLocaleString() : 'N/A'}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Quantity Received</span><span className="pv-kv-value">{data.collection?.quantityKg || data.collectionProcessing?.quantityReceivedKg || 'N/A'} kg</span></div>
            <h4 style={{ margin: '20px 0 10px 0', fontSize: '13px', textTransform: 'uppercase', color: 'var(--text-secondary)', borderBottom: '1px solid var(--border-color)', paddingBottom: '6px' }}>Processing Details</h4>
            <div className="pv-kv-row"><span className="pv-kv-label">Processor</span><span className="pv-kv-value">{data.processing?.processor || data.collectionProcessing?.processor || 'N/A'}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Processing Method</span><span className="pv-kv-value">{data.processing?.method || data.collectionProcessing?.method || 'N/A'}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Input Quantity</span><span className="pv-kv-value">{data.processing?.inputQuantityKg || data.collectionProcessing?.inputQuantityKg || 'N/A'} kg</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Output Quantity</span><span className="pv-kv-value">{data.processing?.outputQuantityKg || data.collectionProcessing?.outputQuantityKg || 'N/A'} kg</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Status</span><span className="pv-kv-value">{data.processing?.status || data.collection?.status || 'Processed'}</span></div>
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
            
            <h4 style={{ margin: '24px 0 12px 0', fontSize: '14px', textTransform: 'uppercase', color: 'var(--text-secondary)', borderBottom: '1px solid var(--border-color)', paddingBottom: '8px' }}>Test Results Summary</h4>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1px', background: 'var(--border-color)', border: '1px solid var(--border-color)', borderRadius: '12px', overflow: 'hidden' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 60px', background: 'var(--surface-color)', padding: '10px 12px', fontSize: '12px', fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase' }}>
                <div>Test</div>
                <div>Result</div>
                <div style={{textAlign: 'right'}}>Status</div>
              </div>
              {data.labVerification!.parameters.map((param, i) => (
                <div key={i} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 60px', background: 'var(--bg-color)', padding: '12px', fontSize: '13px', alignItems: 'center' }}>
                  <div style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{param.name}</div>
                  <div style={{ color: 'var(--text-secondary)' }}>{param.value}</div>
                  <div style={{ textAlign: 'right', fontWeight: 700, color: param.status.toLowerCase() === 'pass' ? '#10b981' : '#ef4444' }}>{param.status}</div>
                </div>
              ))}
            </div>
            <div style={{ marginTop: '24px', textAlign: 'center' }}>
                <button
                  onClick={() => setActiveStage('lab_report')}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '8px',
                    background: 'var(--text-primary)',
                    color: 'var(--bg-color)',
                    padding: '12px 24px',
                    borderRadius: '9999px',
                    fontWeight: 700,
                    fontSize: '14px',
                    cursor: 'pointer',
                    border: 'none',
                    transition: 'opacity 0.2s ease'
                  }}
                >
                  <FiFileText size={16} />
                  View Lab Report
                </button>
            </div>
          </div>
        );
      case 'lab_report':
        const lab = data.labVerification;
        if (!lab) return null;
        return (
          <div className="pv-lab-report" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            
            {/* Header Banner */}
            <div style={{ textAlign: 'center', padding: '16px', background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '16px' }}>
              <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', color: 'var(--accent-color)', marginBottom: '6px' }}>
                <FiAward size={20} />
                <span style={{ fontSize: '12px', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '1px' }}>Official Laboratory Certificate</span>
              </div>
              <h3 style={{ fontSize: '18px', fontWeight: 800, margin: '4px 0', color: 'var(--text-primary)' }}>{lab.labName}</h3>
              <p style={{ fontSize: '13px', color: 'var(--text-secondary)', margin: 0 }}>Report ID: <strong style={{ fontFamily: 'monospace', color: 'var(--text-primary)' }}>{lab.reportId}</strong></p>
            </div>

            {/* Overview Meta Grid */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '12px' }}>
              <div style={{ padding: '12px', background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px' }}>
                <span style={{ fontSize: '11px', textTransform: 'uppercase', color: 'var(--text-secondary)', display: 'block', marginBottom: '4px' }}>Sample ID</span>
                <strong style={{ fontSize: '13px', fontFamily: 'monospace', color: 'var(--text-primary)' }}>{lab.sampleId || lab.sampleCode || 'N/A'}</strong>
              </div>
              <div style={{ padding: '12px', background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px' }}>
                <span style={{ fontSize: '11px', textTransform: 'uppercase', color: 'var(--text-secondary)', display: 'block', marginBottom: '4px' }}>Batch ID</span>
                <strong style={{ fontSize: '13px', fontFamily: 'monospace', color: 'var(--text-primary)' }}>{data.batchId}</strong>
              </div>
              <div style={{ padding: '12px', background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px' }}>
                <span style={{ fontSize: '11px', textTransform: 'uppercase', color: 'var(--text-secondary)', display: 'block', marginBottom: '4px' }}>Sample Date</span>
                <strong style={{ fontSize: '13px', color: 'var(--text-primary)' }}>{formatDate(lab.sampleDate)}</strong>
              </div>
              <div style={{ padding: '12px', background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px' }}>
                <span style={{ fontSize: '11px', textTransform: 'uppercase', color: 'var(--text-secondary)', display: 'block', marginBottom: '4px' }}>Test Date</span>
                <strong style={{ fontSize: '13px', color: 'var(--text-primary)' }}>{formatDate(lab.testDate)}</strong>
              </div>
              <div style={{ padding: '12px', background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px' }}>
                <span style={{ fontSize: '11px', textTransform: 'uppercase', color: 'var(--text-secondary)', display: 'block', marginBottom: '4px' }}>Report Date</span>
                <strong style={{ fontSize: '13px', color: 'var(--text-primary)' }}>{formatDate(lab.reportDate)}</strong>
              </div>
              <div style={{ padding: '12px', background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px' }}>
                <span style={{ fontSize: '11px', textTransform: 'uppercase', color: 'var(--text-secondary)', display: 'block', marginBottom: '4px' }}>Test Type</span>
                <strong style={{ fontSize: '13px', color: 'var(--text-primary)' }}>{lab.testType || 'Honey Purity Analysis'}</strong>
              </div>
            </div>

            {/* Overall Score & Pass/Fail Card */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px', background: 'rgba(16, 185, 129, 0.08)', border: '1px solid rgba(16, 185, 129, 0.3)', borderRadius: '16px' }}>
              <div>
                <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-secondary)', display: 'block', marginBottom: '2px' }}>Overall Result</span>
                <span style={{ fontSize: '18px', fontWeight: 800, color: '#10b981', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <FiCheckCircle size={20} />
                  {lab.overallResult || lab.status || 'PASS'}
                </span>
                {lab.purityGrade && (
                  <span style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px', display: 'block' }}>Purity Grade: <strong>{lab.purityGrade}</strong></span>
                )}
              </div>
              <div style={{ textAlign: 'right' }}>
                <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-secondary)', display: 'block', marginBottom: '2px' }}>Quality Score</span>
                <span style={{ fontSize: '24px', fontWeight: 900, color: 'var(--text-primary)' }}>{lab.qualityScore}<span style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-secondary)' }}>/100</span></span>
              </div>
            </div>

            {/* Test Parameters & Results Table */}
            <div>
              <h4 style={{ fontSize: '13px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--text-secondary)', marginBottom: '10px', letterSpacing: '0.5px' }}>
                Tested Parameters & Results
              </h4>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '1px', background: 'var(--border-color)', border: '1px solid var(--border-color)', borderRadius: '16px', overflow: 'hidden' }}>
                <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr 1fr 60px', background: 'var(--surface-color)', padding: '12px 14px', fontSize: '11px', fontWeight: 800, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                  <div>Parameter</div>
                  <div>Measured Value</div>
                  <div>Standard Limit</div>
                  <div style={{ textAlign: 'right' }}>Status</div>
                </div>
                {lab.parameters.map((param, idx) => (
                  <div key={idx} style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr 1fr 60px', background: 'var(--bg-color)', padding: '12px 14px', fontSize: '13px', alignItems: 'center', borderTop: idx > 0 ? '1px solid var(--border-color)' : 'none' }}>
                    <div style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{param.name}</div>
                    <div style={{ color: 'var(--text-primary)', fontWeight: 600 }}>{param.value}</div>
                    <div style={{ color: 'var(--text-secondary)', fontSize: '12px' }}>{param.standard}</div>
                    <div style={{ textAlign: 'right', fontWeight: 800, color: param.status.toLowerCase() === 'pass' ? '#10b981' : '#ef4444' }}>
                      {param.status}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Remarks */}
            {lab.remarks && (
              <div style={{ padding: '14px 16px', background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '14px' }}>
                <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-secondary)', display: 'block', marginBottom: '4px' }}>Remarks & Certification Notes</span>
                <p style={{ fontSize: '13px', color: 'var(--text-primary)', margin: 0, lineHeight: 1.5 }}>{lab.remarks}</p>
              </div>
            )}

            {/* Certification & Document Hash */}
            <div style={{ padding: '14px 16px', background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '14px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)' }}>
                <FiShield size={16} style={{ color: '#10b981' }} />
                <span style={{ fontSize: '12px', fontWeight: 700, textTransform: 'uppercase' }}>{lab.certificationInfo || lab.documentIntegrityStatus || 'Accredited Laboratory Verification'}</span>
              </div>
              {lab.documentHash && (
                <div style={{ fontSize: '11px', color: 'var(--text-secondary)', wordBreak: 'break-all', fontFamily: 'monospace', background: 'var(--bg-color)', padding: '8px 12px', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
                  Hash: {lab.documentHash}
                </div>
              )}
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

  const getStageTitle = () => {
    switch(activeStage) {
      case 'harvester': return '01 Harvester';
      case 'hive': return '02 Hive';
      case 'collection_processing': return '03 Collection & Processing';
      case 'laboratory': return '04 Laboratory Test';
      case 'lab_report': return 'LABORATORY REPORT';
      case 'packaging': return '06 Packaging';
      case 'blockchain': return '07 Blockchain / Integrity';
      default: return '';
    }
  };

  return (
    <div className="pv-container" style={{ maxWidth: '640px', margin: '0 auto', padding: '16px', fontFamily: 'Inter, sans-serif' }}>
      
      {/* Verification Card with rounded corners and clean header without 'HoneyChain' text */}
      <div className="pv-header" style={{ textAlign: 'center', marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 800, color: 'var(--text-primary)', margin: '0 0 20px 0', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
          Honey Traceability & Verification
        </h2>
        
        <div style={{ background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '16px', padding: '20px', textAlign: 'left', display: 'flex', flexDirection: 'column', gap: '12px', boxShadow: '0 4px 12px rgba(0,0,0,0.03)' }}>
            <h3 style={{ fontSize: '13px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--text-secondary)', borderBottom: '1px solid var(--border-color)', paddingBottom: '8px', margin: '0', letterSpacing: '0.5px' }}>Batch Summary</h3>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Batch ID</span><strong style={{ fontFamily: 'monospace' }}>{data.batchId}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Product</span><strong>{data.product?.productName || 'Raw Forest Honey'}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Total Quantity</span><strong>{data.product?.quantityKg || data.packaging?.packageSize}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Current Status</span><strong>{data.status}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Verification Status</span><strong style={{ color: data.isFullyVerified ? '#10b981' : '#f59e0b' }}>{data.isFullyVerified ? '✓ Verified' : 'Pending'}</strong></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}><span style={{ color: 'var(--text-secondary)' }}>Trace ID</span><strong style={{ fontFamily: 'monospace', fontSize: '12px' }}>{data.traceabilityId}</strong></div>
        </div>
      </div>

      <div style={{ marginBottom: '16px', fontSize: '13px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--text-secondary)', letterSpacing: '0.5px' }}>
        Traceability Timeline
      </div>
      
      <div className="pv-workflow" style={{ display: 'flex', flexDirection: 'column', gap: '16px', position: 'relative' }}>
        {/* Timeline connector line */}
        <div style={{ position: 'absolute', left: '24px', top: '24px', bottom: '24px', width: '2px', background: 'var(--border-color)', zIndex: 0 }}></div>
        
        {workflowNodes.map((node) => (
          node.active && (
            <button 
              key={node.id} 
              onClick={() => setActiveStage(node.id)}
              style={{ 
                position: 'relative', zIndex: 1, display: 'flex', justifyContent: 'space-between', alignItems: 'center', 
                background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '16px', 
                padding: '14px 20px', cursor: 'pointer', textAlign: 'left', width: '100%',
                boxShadow: '0 2px 8px rgba(0,0,0,0.02)', transition: 'all 0.2s ease'
              }}
              onMouseOver={(e) => { e.currentTarget.style.borderColor = 'var(--accent-color)'; e.currentTarget.style.transform = 'translateY(-1px)'; }}
              onMouseOut={(e) => { e.currentTarget.style.borderColor = 'var(--border-color)'; e.currentTarget.style.transform = 'translateY(0)'; }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <span style={{ fontSize: '15px', fontWeight: 700, color: 'var(--text-primary)' }}>{node.title}</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--text-primary)', background: 'var(--bg-color)', padding: '6px 14px', borderRadius: '9999px', border: '1px solid var(--border-color)' }}>
                <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px' }}>Tap to View</span>
                <FiChevronRight size={15} style={{ color: 'var(--text-secondary)' }} />
              </div>
            </button>
          )
        ))}
        
        {data.isFullyVerified && (
             <div style={{ position: 'relative', zIndex: 1, display: 'flex', alignItems: 'center', gap: '12px', padding: '14px 24px', background: '#10b981', color: '#fff', borderRadius: '16px', fontWeight: 800, boxShadow: '0 4px 12px rgba(16, 185, 129, 0.2)' }}>
                 <FiCheckCircle size={20} />
                 <span>VERIFIED HONEY PURITY & TRACEABILITY</span>
             </div>
        )}
      </div>

      <div className="pv-footer" style={{ marginTop: '40px', background: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '16px', padding: '24px' }}>
        <h2 className="pv-section-title" style={{ fontSize: '15px', fontWeight: 800, marginBottom: '16px', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
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
        <div className="modal-overlay" onClick={() => setActiveStage(null)} style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.65)', backdropFilter: 'blur(4px)', zIndex: 100, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}>
          <div className="modal-content" onClick={e => e.stopPropagation()} style={{ background: 'var(--bg-color)', width: '100%', maxWidth: '640px', maxHeight: '90vh', borderTopLeftRadius: '24px', borderTopRightRadius: '24px', display: 'flex', flexDirection: 'column', overflow: 'hidden', animation: 'slideUp 0.3s ease-out', boxShadow: '0 -8px 32px rgba(0,0,0,0.2)' }}>
            
            {/* Modal Header */}
            <div className="modal-header" style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'var(--surface-color)', position: 'relative' }}>
              
              {/* Back Button: ONLY React Icon Arrow, no 'Back' text */}
              <button 
                onClick={() => setActiveStage(null)} 
                aria-label="Back" 
                title="Back"
                style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  justifyContent: 'center', 
                  width: '36px', 
                  height: '36px', 
                  background: 'var(--bg-color)', 
                  border: '1px solid var(--border-color)', 
                  borderRadius: '50%', 
                  color: 'var(--text-primary)', 
                  cursor: 'pointer', 
                  transition: 'all 0.2s ease' 
                }} 
                onMouseOver={(e) => e.currentTarget.style.borderColor = 'var(--text-primary)'} 
                onMouseOut={(e) => e.currentTarget.style.borderColor = 'var(--border-color)'}
              >
                <FiArrowLeft size={18} />
              </button>
              
              <h2 className="modal-title" style={{ fontSize: '15px', fontWeight: 800, margin: 0, textTransform: 'uppercase', letterSpacing: '0.5px', color: 'var(--text-primary)' }}>
                {getStageTitle()}
              </h2>
              
              {/* Close Icon: React Icon FiX */}
              <button 
                onClick={() => setActiveStage(null)} 
                aria-label="Close modal" 
                title="Close"
                style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  justifyContent: 'center', 
                  width: '36px', 
                  height: '36px', 
                  background: 'var(--bg-color)', 
                  border: '1px solid var(--border-color)', 
                  borderRadius: '50%', 
                  color: 'var(--text-primary)', 
                  cursor: 'pointer',
                  transition: 'all 0.2s ease'
                }}
                onMouseOver={(e) => e.currentTarget.style.borderColor = 'var(--text-primary)'} 
                onMouseOut={(e) => e.currentTarget.style.borderColor = 'var(--border-color)'}
              >
                <FiX size={18} />
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
