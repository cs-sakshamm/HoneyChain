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

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetchVerificationData(batchId);
      setData(res);
    } catch (err: any) {
      setError(t.error);
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
      <div className="pv-message-container">
        <p className="pv-message">{t.loading}</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="pv-message-container">
        <p className="pv-message error-text">{error}</p>
      </div>
    );
  }

  if (data && !data.found) {
    return (
      <div className="pv-message-container">
        <h2 className="pv-message-title">{t.notFound}</h2>
      </div>
    );
  }

  if (!data) return null;

  const hasHarvester = !!data.harvester && data.harvester.name !== 'No data available yet.';
  const hasHive = !!data.harvester && data.harvester.hiveCode !== 'No data available yet.';
  const hasCollection = !!data.collectionProcessing && data.collectionProcessing.processor !== 'No data available yet.';
  const hasLabTest = !!data.labVerification && data.labVerification.labName !== 'No data available yet.';
  const hasLabReport = hasLabTest && data.labVerification && data.labVerification.parameters && data.labVerification.parameters.length > 0;
  const hasPackaging = !!data.packaging && data.packaging.facility !== 'No data available yet.';

  const workflowNodes = [
    { id: 'harvester', title: t.nodes.harvester, active: hasHarvester },
    { id: 'hive', title: t.nodes.hive, active: hasHive },
    { id: 'collection', title: t.nodes.collection, active: hasCollection },
    { id: 'laboratory', title: t.nodes.laboratory, active: hasLabTest },
    { id: 'lab_report', title: t.nodes.lab_report, active: hasLabReport },
    { id: 'packaging', title: t.nodes.packaging, active: hasPackaging }
  ];

  const renderModalContent = () => {
    switch (activeStage) {
      case 'harvester':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Harvester Name</span><span className="pv-kv-value">{data.harvester.name}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Harvester ID</span><span className="pv-kv-value">{data.harvester.beekeeperId}</span></div>
            {data.harvester.apiaryLocation !== 'No data available yet.' && (
              <div className="pv-kv-row"><span className="pv-kv-label">Location</span><span className="pv-kv-value">{data.harvester.apiaryLocation}</span></div>
            )}
            {data.harvester.beeBreed !== 'Unknown' && (
              <div className="pv-kv-row"><span className="pv-kv-label">Bee Breed</span><span className="pv-kv-value">{data.harvester.beeBreed}</span></div>
            )}
          </div>
        );
      case 'hive':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Hive ID</span><span className="pv-kv-value">{data.harvester.hiveCode}</span></div>
            {data.iotTelemetry && data.iotTelemetry.temperature !== 'No IoT telemetry available yet.' && (
              <>
                <div className="pv-kv-row"><span className="pv-kv-label">Temperature</span><span className="pv-kv-value">{data.iotTelemetry.temperature}</span></div>
                <div className="pv-kv-row"><span className="pv-kv-label">Humidity</span><span className="pv-kv-value">{data.iotTelemetry.humidity}</span></div>
                <div className="pv-kv-row"><span className="pv-kv-label">Weight</span><span className="pv-kv-value">{data.iotTelemetry.weight}</span></div>
                <div className="pv-kv-row"><span className="pv-kv-label">Recorded At</span><span className="pv-kv-value">{new Date(data.iotTelemetry.recordedAt).toLocaleString()}</span></div>
              </>
            )}
          </div>
        );
      case 'collection':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Collection Center</span><span className="pv-kv-value">{data.collectionProcessing!.processor}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Processing Method</span><span className="pv-kv-value">{data.collectionProcessing!.method}</span></div>
            {data.collectionProcessing!.quantityReceivedKg !== 'No data available yet.' && (
              <div className="pv-kv-row"><span className="pv-kv-label">Quantity Received</span><span className="pv-kv-value">{data.collectionProcessing!.quantityReceivedKg} kg</span></div>
            )}
            <div className="pv-kv-row"><span className="pv-kv-label">Status</span><span className="pv-kv-value">Processed</span></div>
          </div>
        );
      case 'laboratory':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Laboratory Name</span><span className="pv-kv-value">{data.labVerification!.labName}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Report Number</span><span className="pv-kv-value">{data.labVerification!.reportId}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Test Result</span><span className="pv-kv-value" style={{fontWeight: 700}}>{data.labVerification!.status}</span></div>
          </div>
        );
      case 'lab_report':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Laboratory</span><span className="pv-kv-value">{data.labVerification!.labName}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Report Number</span><span className="pv-kv-value">{data.labVerification!.reportId}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Quality Score</span><span className="pv-kv-value">{data.labVerification!.qualityScore}/100</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Overall Status</span><span className="pv-kv-value" style={{fontWeight: 700}}>{data.labVerification!.status}</span></div>
            
            <h4 style={{ margin: '16px 0 8px 0', fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)', borderBottom: '1px solid var(--border-color)', paddingBottom: '4px' }}>Detailed Parameters</h4>
            {data.labVerification!.parameters.map((param, i) => (
              <div className="pv-kv-row" key={i} style={{ flexDirection: 'column', alignItems: 'flex-start', padding: '12px 0', gap: '6px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%' }}>
                  <span className="pv-kv-label" style={{ color: 'var(--text-primary)', fontSize: '14px' }}>{param.name}</span>
                  <span className="pv-kv-value" style={{ 
                    fontWeight: 700, 
                    fontSize: '13px',
                    color: param.status === 'Pass' ? '#10b981' : param.status === 'Fail' ? '#ef4444' : 'var(--text-secondary)'
                  }}>{param.status}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%', fontSize: '13px', color: 'var(--text-secondary)' }}>
                  <span>Result: <strong>{param.value}</strong></span>
                  <span>Standard: {param.standard}</span>
                </div>
              </div>
            ))}
          </div>
        );
      case 'packaging':
        return (
          <div className="pv-kv-list">
            <div className="pv-kv-row"><span className="pv-kv-label">Packaging Facility</span><span className="pv-kv-value">{data.packaging!.facility}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Batch ID</span><span className="pv-kv-value">{data.batchId}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Packaging Date</span><span className="pv-kv-value">{new Date(data.packaging!.packagingDate).toLocaleDateString()}</span></div>
            <div className="pv-kv-row"><span className="pv-kv-label">Seal Status</span><span className="pv-kv-value">{data.packaging!.sealStatus}</span></div>
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="pv-container">
      <div className="pv-header">
        <h1 style={{ fontSize: '24px', fontWeight: 800, margin: '0 0 4px 0', letterSpacing: '-0.5px' }}>HoneyChain</h1>
        <h2 style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-secondary)', margin: '0 0 16px 0', textTransform: 'uppercase' }}>Honey Traceability & Verification</h2>
        <div className="pv-status-badge" style={{ backgroundColor: data.isFullyVerified ? '#10b981' : '#f59e0b' }}>
          {data.isFullyVerified ? 'VERIFIED' : 'PENDING'}
        </div>
        <p className="pv-trace-id" style={{ marginTop: '12px', fontWeight: 600 }}>{t.traceId}: {data.batchId || batchId}</p>
      </div>

      <div className="pv-workflow">
        {workflowNodes.map((node) => (
          node.active && (
            <button 
              key={node.id} 
              className="pv-workflow-node"
              onClick={() => setActiveStage(node.id)}
            >
              {node.title}
            </button>
          )
        ))}
      </div>

      <div className="pv-footer" style={{ marginTop: '24px', textAlign: 'center', borderTop: '1px solid var(--border-color)', paddingTop: '24px' }}>
        <h2 className="pv-section-title" style={{ fontSize: '18px', fontWeight: 800 }}>
          {data.isFullyVerified ? t.traceability : 'INCOMPLETE TRACEABILITY'}
        </h2>
        <p className="pv-trace-status" style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
          {data.status}
        </p>
      </div>

      {activeStage && (
        <div className="modal-overlay" onClick={() => setActiveStage(null)}>
          <div className="modal-content" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2 className="modal-title">
                {workflowNodes.find(n => n.id === activeStage)?.title.substring(3)}
              </h2>
              <button className="modal-close" onClick={() => setActiveStage(null)}>{t.close}</button>
            </div>
            <div className="modal-body">
              {renderModalContent()}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
