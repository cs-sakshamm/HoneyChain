import React from 'react';
import { Package, ShieldCheck, MapPin, Award } from 'lucide-react';
import { ProductInfo, HarvesterInfo } from '../api/honeychainApi';

interface Props {
  product: ProductInfo;
  harvester: HarvesterInfo;
  status: string;
  isFullyVerified: boolean;
  batchId: string;
}

export const ProductSummary: React.FC<Props> = ({ product, harvester, status, isFullyVerified, batchId }) => {
  return (
    <div className="honey-card">
      <div className="card-header-row">
        <div className="card-title-group">
          <div className={`card-title-icon ${isFullyVerified ? 'success' : ''}`}>
            <ShieldCheck size={20} />
          </div>
          <div>
            <h1 className="card-title" style={{ fontSize: '18px' }}>
              {product?.productName || 'Raw Natural Honey'}
            </h1>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Batch: <span style={{ fontFamily: 'var(--font-mono)', color: 'var(--primary-gold)' }}>{batchId}</span>
            </div>
          </div>
        </div>
        <span className={`status-pill ${isFullyVerified ? 'success' : 'gold'}`}>
          {isFullyVerified ? '✓ Verified Genuine' : status}
        </span>
      </div>

      <div className="kv-grid" style={{ marginBottom: '14px' }}>
        <div className="kv-item">
          <div className="kv-label">Product ID</div>
          <div className="kv-value mono">{product?.productId || `HONEY-${batchId}`}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Quantity / Volume</div>
          <div className="kv-value highlight">{product?.quantityKg || '24.0'} kg</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Package Format</div>
          <div className="kv-value">{product?.packageSize || '500g Glass Jar'}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Induction Seal</div>
          <div className="kv-value" style={{ color: 'var(--success-green)' }}>
            {product?.sealType || 'Induction Tamper-Evident Seal'}
          </div>
        </div>
      </div>

      <div style={{ borderTop: '1px solid var(--border-subtle)', paddingTop: '12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px', color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 700, textTransform: 'uppercase' }}>
          <MapPin size={14} color="var(--primary-gold)" /> Origin & Beekeeper
        </div>
        <div className="kv-grid">
          <div className="kv-item">
            <div className="kv-label">Beekeeper / Harvester</div>
            <div className="kv-value">{harvester?.name || 'Security Harvester'}</div>
          </div>
          <div className="kv-item">
            <div className="kv-label">Apiary Location</div>
            <div className="kv-value">{harvester?.apiaryLocation || 'Forest Reserve Apiary'}</div>
          </div>
          <div className="kv-item">
            <div className="kv-label">Hive Code</div>
            <div className="kv-value mono">{harvester?.hiveCode || 'HIVE-MVP-01'}</div>
          </div>
          <div className="kv-item">
            <div className="kv-label">Bee Breed / Queen</div>
            <div className="kv-value">{harvester?.beeBreed || 'Apis cerana indica'} ({harvester?.queenStatus || 'Mated'})</div>
          </div>
        </div>
      </div>
    </div>
  );
};
