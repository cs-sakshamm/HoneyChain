import React, { useState } from 'react';
import { FlaskConical, CheckCircle, FileText, Download, X } from 'lucide-react';
import { LabVerificationInfo } from '../api/honeychainApi';
import { motion, AnimatePresence, useReducedMotion } from 'framer-motion';
import { getHoverProps, getButtonProps } from '../utils/animations';

interface Props {
  lab: LabVerificationInfo | null;
  batchId: string;
}

export const LabReport: React.FC<Props> = ({ lab, batchId }) => {
  const [showCertificateModal, setShowCertificateModal] = useState(false);
  const shouldReduceMotion = useReducedMotion();
  const hoverProps = getHoverProps(shouldReduceMotion ?? false);
  const buttonProps = getButtonProps(shouldReduceMotion ?? false);

  if (!lab) {
    return (
      <motion.div className="honey-card" {...hoverProps}>
        <div className="card-header-row">
          <div className="card-title-group">
            <div className="card-title-icon">
              <FlaskConical size={20} />
            </div>
            <div>
              <h2 className="card-title">Laboratory Chemical & Quality Analysis</h2>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Analytical chemical certification</div>
            </div>
          </div>
        </div>
        <p style={{ color: 'var(--text-muted)', fontStyle: 'italic', fontSize: '13px' }}>
          Laboratory report not available for this batch.
        </p>
      </motion.div>
    );
  }

  const isApproved = lab.status.toUpperCase().includes('PASS') || lab.status.toUpperCase().includes('APPROV');

  return (
    <motion.div className="honey-card" {...hoverProps}>
      <div className="card-header-row">
        <div className="card-title-group">
          <div className={`card-title-icon ${isApproved ? 'success' : ''}`}>
            <FlaskConical size={20} />
          </div>
          <div>
            <h2 className="card-title">Laboratory Chemical & Quality Analysis</h2>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Accredited analytical report conforming to Codex Alimentarius & FSSAI
            </div>
          </div>
        </div>
        <span className={`status-pill ${isApproved ? 'success' : 'danger'}`}>
          <CheckCircle size={12} /> {lab.status}
        </span>
      </div>

      <div className="kv-grid" style={{ marginBottom: '14px' }}>
        <div className="kv-item">
          <div className="kv-label">Accredited Testing Facility</div>
          <div className="kv-value">{lab.labName}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Report Number</div>
          <div className="kv-value mono">{lab.reportId}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Quality Purity Score</div>
          <div className="kv-value highlight">{lab.qualityScore} / 100</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Accreditation Standards</div>
          <div className="kv-value">NABL / ISO 17025 / FSSAI</div>
        </div>
      </div>

      {lab.parameters && lab.parameters.length > 0 && (
        <div className="lab-table-container">
          <table className="lab-table">
            <thead>
              <tr>
                <th>Test Parameter</th>
                <th>Measured Value</th>
                <th>Standard Limit</th>
                <th>Result</th>
              </tr>
            </thead>
            <tbody>
              {lab.parameters.map((p, idx) => (
                <tr key={idx}>
                  <td style={{ fontWeight: 600 }}>{p.name}</td>
                  <td style={{ fontFamily: 'var(--font-mono)', color: 'var(--primary-gold)' }}>{p.value}</td>
                  <td style={{ color: 'var(--text-muted)' }}>{p.standard}</td>
                  <td>
                    <span className="status-pill success" style={{ fontSize: '10px', padding: '1px 6px' }}>
                      {p.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div style={{ marginTop: '14px', display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
        <motion.button
          {...buttonProps}
          onClick={() => setShowCertificateModal(true)}
          className="btn-primary"
          style={{ flex: 1, minWidth: '160px', padding: '8px 14px', fontSize: '13px' }}
        >
          <Download size={15} /> Download Lab Report
        </motion.button>
        <motion.button
          {...buttonProps}
          onClick={() => setShowCertificateModal(true)}
          className="btn-secondary"
          style={{ flex: 1, minWidth: '160px', padding: '8px 14px', fontSize: '13px', background: 'rgba(255,255,255,0.06)', border: '1px solid var(--border-color)', borderRadius: '8px', color: 'var(--text-primary)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
        >
          <FileText size={15} /> View Analytical Certificate
        </motion.button>
      </div>

      <AnimatePresence>
        {showCertificateModal && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            style={{
              position: 'fixed',
              inset: 0,
              backgroundColor: 'rgba(0, 0, 0, 0.75)',
              backdropFilter: 'blur(4px)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              zIndex: 1000,
              padding: '16px',
            }}
          >
            <motion.div
              initial={{ opacity: 0, scale: shouldReduceMotion ? 1 : 0.96 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: shouldReduceMotion ? 1 : 0.96 }}
              transition={{ duration: 0.2 }}
              style={{
                backgroundColor: 'var(--bg-card)',
                border: '1px solid var(--border-color)',
                borderRadius: '16px',
                maxWidth: '560px',
                width: '100%',
                padding: '24px',
                maxHeight: '90vh',
                overflowY: 'auto',
                position: 'relative',
              }}
            >
              <button
                onClick={() => setShowCertificateModal(false)}
                style={{
                  position: 'absolute',
                  top: '16px',
                  right: '16px',
                  color: 'var(--text-secondary)',
                  padding: '4px',
                }}
              >
                <X size={20} />
              </button>

              <div style={{ textAlign: 'center', marginBottom: '16px' }}>
                <div style={{ color: 'var(--primary-gold)', fontWeight: 800, fontSize: '18px' }}>
                  CERTIFICATE OF ANALYSIS
                </div>
                <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                  HoneyChain Trust & Traceability Protocol
                </div>
              </div>

              <div className="kv-grid" style={{ marginBottom: '16px' }}>
                <div className="kv-item">
                  <div className="kv-label">Report ID</div>
                  <div className="kv-value mono">{lab.reportId}</div>
                </div>
                <div className="kv-item">
                  <div className="kv-label">Batch Code</div>
                  <div className="kv-value mono">{batchId}</div>
                </div>
                <div className="kv-item">
                  <div className="kv-label">Laboratory</div>
                  <div className="kv-value">{lab.labName}</div>
                </div>
                <div className="kv-item">
                  <div className="kv-label">Overall Result</div>
                  <div className="kv-value" style={{ color: 'var(--success-green)' }}>{lab.status}</div>
                </div>
              </div>

              <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginBottom: '16px', lineHeight: 1.6 }}>
                This document certifies that the aforementioned lot sample underwent comprehensive physicochemical testing. All measured parameters, including moisture content, diastase enzyme levels, HMF index, and pollen origin, conform strictly with Codex Alimentarius and FSSAI honey quality standards.
              </div>

              <motion.button
                {...buttonProps}
                onClick={() => window.print()}
                className="btn-primary"
                style={{ width: '100%' }}
              >
                <Download size={16} /> Print / Save Certificate
              </motion.button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
};
