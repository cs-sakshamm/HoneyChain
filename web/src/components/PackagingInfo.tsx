import React from 'react';
import { Box, CheckCircle, Clock } from 'lucide-react';
import { PackagingInfoData, ProcessingInfo } from '../api/honeychainApi';
import { motion, useReducedMotion } from 'framer-motion';
import { getHoverProps } from '../utils/animations';

interface Props {
  packaging: PackagingInfoData | null;
  processing: ProcessingInfo | null;
  batchId: string;
}

const valueOrMissing = (value: unknown) => {
  if (value === null || value === undefined || value === '') return 'No data available yet';
  return String(value);
};

export const PackagingInfo: React.FC<Props> = ({ packaging, processing }) => {
  const packaged = Boolean(packaging);
  const shouldReduceMotion = useReducedMotion();
  const hoverProps = getHoverProps(shouldReduceMotion ?? false);

  return (
    <motion.div className="honey-card" {...hoverProps}>
      <div className="card-header-row">
        <div className="card-title-group">
          <div className={`card-title-icon ${packaged ? 'success' : ''}`}>
            <Box size={20} />
          </div>
          <div>
            <h2 className="card-title">Processing & Packaging Facility</h2>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Extraction, bottling and tamper-evident seal status
            </div>
          </div>
        </div>
        <span className={`status-pill ${packaged ? 'success' : 'gold'}`} style={{ fontSize: '11px' }}>
          {packaged ? <CheckCircle size={12} /> : <Clock size={12} />} {packaged ? 'Packaged & Sealed' : 'Packaging Pending'}
        </span>
      </div>

      <div className="kv-grid" style={{ marginBottom: '14px' }}>
        <div className="kv-item">
          <div className="kv-label">Processing Center</div>
          <div className="kv-value">{valueOrMissing(processing?.processor)}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Extraction Technology</div>
          <div className="kv-value">{valueOrMissing(processing?.method)}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Packaging Facility</div>
          <div className="kv-value">{valueOrMissing(packaging?.facility)}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Packaging Date</div>
          <div className="kv-value">
            {packaging?.packagingDate ? new Date(packaging.packagingDate).toLocaleDateString() : 'No data available yet'}
          </div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Units Produced</div>
          <div className="kv-value highlight">{valueOrMissing(packaging?.numberOfPackages)}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Seal Integrity</div>
          <div className="kv-value" style={{ color: packaged ? 'var(--success-green)' : 'var(--text-secondary)' }}>
            {valueOrMissing(packaging?.sealStatus)}
          </div>
        </div>
      </div>
    </motion.div>
  );
};
