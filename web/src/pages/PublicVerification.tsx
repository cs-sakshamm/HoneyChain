import React, { useEffect, useState } from 'react';
import { fetchVerificationData, VerificationResponse } from '../api/honeychainApi';
import '../styles/PublicVerification.css';

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
      setError('Verification service is temporarily unavailable. Please try again.');
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
      <div className="pv-container">
        <div className="pv-wrapper">
          <div className="pv-center-msg">
            <p className="pv-center-desc">Verifying record...</p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="pv-container">
        <div className="pv-wrapper">
          <div className="pv-center-msg">
            <h2 className="pv-center-title">Error</h2>
            <p className="pv-center-desc">{error}</p>
          </div>
        </div>
      </div>
    );
  }

  if (data && !data.found) {
    return (
      <div className="pv-container">
        <div className="pv-wrapper">
          <div className="pv-center-msg">
            <h2 className="pv-center-title">Traceability Record Not Found</h2>
            <p className="pv-center-desc">Invalid Traceability Code.</p>
          </div>
        </div>
      </div>
    );
  }

  if (!data) return null;

  const hasHarvester = !!data.harvester && data.harvester.name !== 'No data available yet.';
  const hasHive = !!data.harvester && data.harvester.hiveCode !== 'No data available yet.';
  const hasCollection = !!data.collectionProcessing && data.collectionProcessing.processor !== 'No data available yet.';
  const hasLabTest = !!data.labVerification && data.labVerification.labName !== 'No data available yet.';
  const hasPackaging = !!data.packaging && data.packaging.facility !== 'No data available yet.';
  
  const isFullyVerified = data.isFullyVerified;

  return (
    <div className="pv-container">
      <div className="pv-wrapper">
        
        {/* Header */}
        <header className="pv-header">
          <h1 className="pv-header-title">HoneyChain</h1>
          <p className="pv-header-subtitle">Honey Traceability & Verification</p>
        </header>

        <hr className="pv-divider" />

        {/* Verification Status */}
        <div className="pv-status-section">
          <h2 className="pv-status-title">Product Verification</h2>
          <div className="pv-status-badge">
            VERIFIED
          </div>
          <div className="pv-status-trace">
            Trace ID: {data.batchId || batchId}
          </div>
        </div>

        <hr className="pv-divider" />

        <h2 className="pv-main-heading">Traceability</h2>

        {/* 01 Harvester */}
        {hasHarvester && (
          <div className="pv-step">
            <div className="pv-step-header">
              <span className="pv-step-number">01</span>
              <h3 className="pv-step-title">Harvester</h3>
            </div>
            <div className="pv-kv-list">
              <div className="pv-kv-row">
                <span className="pv-kv-label">Full Name</span>
                <span className="pv-kv-value">{data.harvester.name}</span>
              </div>
              <div className="pv-kv-row">
                <span className="pv-kv-label">Harvester ID</span>
                <span className="pv-kv-value">{data.harvester.beekeeperId}</span>
              </div>
              {data.harvester.hiveCode !== 'No data available yet.' && (
                <div className="pv-kv-row">
                  <span className="pv-kv-label">Hive ID</span>
                  <span className="pv-kv-value">{data.harvester.hiveCode}</span>
                </div>
              )}
              {data.harvester.apiaryLocation !== 'No data available yet.' && (
                <div className="pv-kv-row">
                  <span className="pv-kv-label">Location</span>
                  <span className="pv-kv-value">{data.harvester.apiaryLocation}</span>
                </div>
              )}
            </div>
          </div>
        )}

        {/* 02 Hive */}
        {hasHive && (
          <div className="pv-step">
            <div className="pv-step-header">
              <span className="pv-step-number">02</span>
              <h3 className="pv-step-title">Hive</h3>
            </div>
            <div className="pv-kv-list">
              <div className="pv-kv-row">
                <span className="pv-kv-label">Hive ID</span>
                <span className="pv-kv-value">{data.harvester.hiveCode}</span>
              </div>
              <div className="pv-kv-row">
                <span className="pv-kv-label">Batch ID</span>
                <span className="pv-kv-value">{data.batchId}</span>
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
          </div>
        )}

        {/* 03 Collection */}
        {hasCollection && data.collectionProcessing && (
          <div className="pv-step">
            <div className="pv-step-header">
              <span className="pv-step-number">03</span>
              <h3 className="pv-step-title">Collection & Processing</h3>
            </div>
            <div className="pv-kv-list">
              <div className="pv-kv-row">
                <span className="pv-kv-label">Center Name</span>
                <span className="pv-kv-value">{data.collectionProcessing.processor}</span>
              </div>
              <div className="pv-kv-row">
                <span className="pv-kv-label">Batch ID</span>
                <span className="pv-kv-value">{data.batchId}</span>
              </div>
              {data.collectionProcessing.method !== 'No data available yet.' && (
                <div className="pv-kv-row">
                  <span className="pv-kv-label">Processing Details</span>
                  <span className="pv-kv-value">{data.collectionProcessing.method}</span>
                </div>
              )}
            </div>
          </div>
        )}

        {/* 04 Laboratory */}
        {hasLabTest && data.labVerification && (
          <div className="pv-step">
            <div className="pv-step-header">
              <span className="pv-step-number">04</span>
              <h3 className="pv-step-title">Laboratory Test</h3>
            </div>
            <div className="pv-kv-list">
              <div className="pv-kv-row">
                <span className="pv-kv-label">Laboratory</span>
                <span className="pv-kv-value">{data.labVerification.labName}</span>
              </div>
              {data.labVerification.reportId !== 'No data available yet.' && (
                <div className="pv-kv-row">
                  <span className="pv-kv-label">Report ID</span>
                  <span className="pv-kv-value">{data.labVerification.reportId}</span>
                </div>
              )}
              {data.labVerification.status !== 'No data available yet.' && (
                <div className="pv-kv-row">
                  <span className="pv-kv-label">Result</span>
                  <span className="pv-kv-value">{data.labVerification.status}</span>
                </div>
              )}
            </div>

            {data.labVerification.parameters && data.labVerification.parameters.length > 0 && (
              <div className="pv-sub-section">
                <h4 className="pv-sub-heading">Lab Parameters</h4>
                <div className="pv-kv-list">
                  {data.labVerification.parameters.map((param, idx) => (
                    <div key={idx} className="pv-kv-row">
                      <span className="pv-kv-label">{param.name}</span>
                      <span className="pv-kv-value">{param.value}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* 05 Packaging */}
        {hasPackaging && data.packaging && (
          <div className="pv-step">
            <div className="pv-step-header">
              <span className="pv-step-number">05</span>
              <h3 className="pv-step-title">Packaging</h3>
            </div>
            <div className="pv-kv-list">
              <div className="pv-kv-row">
                <span className="pv-kv-label">Packaging Facility</span>
                <span className="pv-kv-value">{data.packaging.facility}</span>
              </div>
              <div className="pv-kv-row">
                <span className="pv-kv-label">Packaging Date</span>
                <span className="pv-kv-value">{new Date(data.packaging.packagingDate).toLocaleDateString()}</span>
              </div>
              <div className="pv-kv-row">
                <span className="pv-kv-label">Package Info</span>
                <span className="pv-kv-value">{data.packaging.numberOfPackages} × {data.packaging.packageSize}</span>
              </div>
              <div className="pv-kv-row">
                <span className="pv-kv-label">Status</span>
                <span className="pv-kv-value">COMPLETED</span>
              </div>
            </div>
          </div>
        )}

        <hr className="pv-divider" />

        {/* Final Status */}
        <div className="pv-footer-status">
          <h3 className="pv-footer-title">
            {isFullyVerified ? 'Complete Traceability' : 'Traceability Incomplete'}
          </h3>
          <p className="pv-footer-desc">
            {isFullyVerified 
              ? 'All available records have been verified.'
              : 'Some stages of the traceability journey are missing or incomplete.'}
          </p>
        </div>

      </div>
    </div>
  );
};
