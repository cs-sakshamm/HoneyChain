import React from 'react';
import { Box, CheckCircle } from 'lucide-react';
import { PackagingInfoData, ProcessingInfo } from '../api/honeychainApi';

interface Props {
  packaging: PackagingInfoData | null;
  processing: ProcessingInfo | null;
  batchId: string;
}

export const PackagingInfo: React.FC<Props> = ({ packaging, processing, batchId }) => {
  return (
    <div className="honey-card">
      <div className="card-header-row">
        <div className="card-title-group">
          <div className="card-title-icon success">
            <Box size={20} />
          </div>
          <div>
            <h2 className="card-title">Processing & Packaging Facility</h2>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Extraction, quality bottling & tamper-evident seal
            </div>
          </div>
        </div>
        <span className="status-pill success" style={{ fontSize: '11px' }}>
          <CheckCircle size={12} /> Packaged & Sealed
        </span>
      </div>

      <div className="kv-grid" style={{ marginBottom: '14px' }}>
        <div className="kv-item">
          <div className="kv-label">Processing Center</div>
          <div className="kv-value">{processing?.processor || 'Sahyadri Honey Processing Hub'}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Extraction Technology</div>
          <div className="kv-value">{processing?.method || 'Centrifugal Cold Extraction (< 38°C)'}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Packaging Facility</div>
          <div className="kv-value">{packaging?.facility || 'Sahyadri Pure Honey Bottling Unit'}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Packaging Date</div>
          <div className="kv-value">
            {packaging?.packagingDate ? new Date(packaging.packagingDate).toLocaleDateString() : 'September 16, 2026'}
          </div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Units Produced</div>
          <div className="kv-value highlight">{packaging?.numberOfPackages || '48'} Jars</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Seal Integrity</div>
          <div className="kv-value" style={{ color: 'var(--success-green)' }}>
            {packaging?.sealStatus || 'Induction Digital Tamper Seal'}
          </div>
        </div>
      </div>
    </div>
  );
};
