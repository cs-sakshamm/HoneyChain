import React, { useEffect, useState } from 'react';
import { fetchVerificationData, VerificationResponse } from '../api/honeychainApi';

interface Props {
  batchId: string;
}

export const PublicVerification: React.FC<Props> = ({ batchId }) => {
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
      setError('Verification service is temporarily unavailable.');
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
        <p className="pv-message">Verifying record...</p>
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
        <h2 className="pv-message-title">Record not found</h2>
      </div>
    );
  }

  if (!data) return null;

  const hasHarvester = !!data.harvester && data.harvester.name !== 'No data available yet.';
  const hasHive = !!data.harvester && data.harvester.hiveCode !== 'No data available yet.';
  const hasCollection = !!data.collectionProcessing && data.collectionProcessing.processor !== 'No data available yet.';
  const hasLabTest = !!data.labVerification && data.labVerification.labName !== 'No data available yet.';
  const hasPackaging = !!data.packaging && data.packaging.facility !== 'No data available yet.';
  
  return (
    <div className="pv-container">
      
      <div className="pv-header">
        <h1 className="pv-title">Product Verification</h1>
        <div className="pv-status-badge">
          {data.isFullyVerified ? 'VERIFIED' : 'PENDING'}
        </div>
        <p className="pv-trace-id">Trace ID: {data.batchId || batchId}</p>
      </div>

      <div className="pv-sections">
        {hasHarvester && (
          <section className="pv-section">
            <h2 className="pv-section-title">01 Harvester</h2>
            <div className="pv-kv-list">
              <div className="pv-kv-row">
                <span className="pv-kv-label">Name</span>
                <span className="pv-kv-value">{data.harvester.name}</span>
              </div>
              <div className="pv-kv-row">
                <span className="pv-kv-label">Harvester ID</span>
                <span className="pv-kv-value">{data.harvester.beekeeperId}</span>
              </div>
              {data.harvester.apiaryLocation !== 'No data available yet.' && (
                <div className="pv-kv-row">
                  <span className="pv-kv-label">Location</span>
                  <span className="pv-kv-value">{data.harvester.apiaryLocation}</span>
                </div>
              )}
            </div>
          </section>
        )}

        {hasHive && (
          <section className="pv-section">
            <h2 className="pv-section-title">02 Hive</h2>
            <div className="pv-kv-list">
              <div className="pv-kv-row">
                <span className="pv-kv-label">Hive ID</span>
                <span className="pv-kv-value">{data.harvester.hiveCode}</span>
              </div>
              {data.iotTelemetry && data.iotTelemetry.temperature !== 'No IoT telemetry available yet.' && (
                <>
                  <div className="pv-kv-row">
                    <span className="pv-kv-label">Temperature</span>
                    <span className="pv-kv-value">{data.iotTelemetry.temperature}</span>
                  </div>
                  <div className="pv-kv-row">
                    <span className="pv-kv-label">Humidity</span>
                    <span className="pv-kv-value">{data.iotTelemetry.humidity}</span>
                  </div>
                </>
              )}
            </div>
          </section>
        )}

        {hasCollection && data.collectionProcessing && (
          <section className="pv-section">
            <h2 className="pv-section-title">03 Collection & Processing</h2>
            <div className="pv-kv-list">
              <div className="pv-kv-row">
                <span className="pv-kv-label">Center</span>
                <span className="pv-kv-value">{data.collectionProcessing.processor}</span>
              </div>
              <div className="pv-kv-row">
                <span className="pv-kv-label">Details</span>
                <span className="pv-kv-value">{data.collectionProcessing.method}</span>
              </div>
              {data.collectionProcessing.quantityReceivedKg !== 'No data available yet.' && (
                <div className="pv-kv-row">
                  <span className="pv-kv-label">Quantity Received</span>
                  <span className="pv-kv-value">{data.collectionProcessing.quantityReceivedKg} kg</span>
                </div>
              )}
            </div>
          </section>
        )}

        {hasLabTest && data.labVerification && (
          <section className="pv-section">
            <h2 className="pv-section-title">04 Laboratory Test</h2>
            <div className="pv-kv-list">
              <div className="pv-kv-row">
                <span className="pv-kv-label">Lab Name</span>
                <span className="pv-kv-value">{data.labVerification.labName}</span>
              </div>
              <div className="pv-kv-row">
                <span className="pv-kv-label">Report Number</span>
                <span className="pv-kv-value">{data.labVerification.reportId}</span>
              </div>
              <div className="pv-kv-row">
                <span className="pv-kv-label">Test Result</span>
                <span className="pv-kv-value" style={{fontWeight: 700}}>{data.labVerification.status}</span>
              </div>
            </div>

            {data.labVerification.parameters && data.labVerification.parameters.length > 0 && (
              <div className="pv-lab-report">
                <h3 className="pv-sub-title">Lab Report</h3>
                <div className="pv-kv-list">
                  {data.labVerification.parameters.map((param, i) => (
                    <div className="pv-kv-row" key={i}>
                      <span className="pv-kv-label">{param.name}</span>
                      <span className="pv-kv-value">{param.value} ({param.status})</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </section>
        )}

        {hasPackaging && data.packaging && (
          <section className="pv-section">
            <h2 className="pv-section-title">05 Packaging</h2>
            <div className="pv-kv-list">
              <div className="pv-kv-row">
                <span className="pv-kv-label">Facility</span>
                <span className="pv-kv-value">{data.packaging.facility}</span>
              </div>
              <div className="pv-kv-row">
                <span className="pv-kv-label">Packaging Date</span>
                <span className="pv-kv-value">
                  {new Date(data.packaging.packagingDate).toLocaleDateString()}
                </span>
              </div>
              <div className="pv-kv-row">
                <span className="pv-kv-label">Status</span>
                <span className="pv-kv-value">{data.packaging.sealStatus}</span>
              </div>
            </div>
          </section>
        )}
      </div>

      <div className="pv-footer">
        <h2 className="pv-section-title">Complete Traceability</h2>
        <p className="pv-trace-status">{data.status}</p>
      </div>

    </div>
  );
};
