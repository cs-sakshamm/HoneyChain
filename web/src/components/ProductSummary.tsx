import React from 'react';
import { ShieldCheck, MapPin } from 'lucide-react';
import { ProductInfo, HarvesterInfo } from '../api/honeychainApi';
import { motion, AnimatePresence, useReducedMotion } from 'framer-motion';
import { getHoverProps } from '../utils/animations';

interface Props {
  product: ProductInfo;
  harvester: HarvesterInfo;
  status: string;
  isFullyVerified: boolean;
  batchId: string;
}

const valueOrEmpty = (value: unknown) => {
  if (value === null || value === undefined || value === '') return 'No data available yet';
  return String(value);
};

export const ProductSummary: React.FC<Props> = ({ product, harvester, status, isFullyVerified, batchId }) => {
  const shouldReduceMotion = useReducedMotion();
  const hoverProps = getHoverProps(shouldReduceMotion ?? false);

  return (
    <motion.div className="honey-card" {...hoverProps}>
      <div className="card-header-row">
        <div className="card-title-group">
          <div className={`card-title-icon ${isFullyVerified ? 'success' : ''}`}>
            <ShieldCheck size={20} />
          </div>
          <div>
            <h1 className="card-title" style={{ fontSize: '18px' }}>
              {product?.productName || 'HoneyChain Batch'}
            </h1>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Batch: <span style={{ fontFamily: 'var(--font-mono)', color: 'var(--primary-gold)' }}>{batchId}</span>
            </div>
          </div>
        </div>
        <AnimatePresence mode="popLayout">
          <motion.span
            key={isFullyVerified ? 'Complete' : status}
            initial={{ opacity: 0, scale: 0.8, y: -5 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.8, y: 5 }}
            transition={{ duration: 0.2 }}
            className={`status-pill ${isFullyVerified ? 'success' : 'gold'}`}
          >
            {isFullyVerified ? 'Traceability Complete' : status}
          </motion.span>
        </AnimatePresence>
      </div>

      <div className="kv-grid" style={{ marginBottom: '14px' }}>
        <div className="kv-item">
          <div className="kv-label">Product ID</div>
          <div className="kv-value mono">{product?.productId || `HONEY-${batchId}`}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Quantity / Volume</div>
          <div className="kv-value highlight">{valueOrEmpty(product?.quantityKg)} kg</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Package Format</div>
          <div className="kv-value">{valueOrEmpty(product?.packageSize)}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Induction Seal</div>
          <div className="kv-value" style={{ color: 'var(--success-green)' }}>
            {valueOrEmpty(product?.sealType)}
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
            <div className="kv-value">{valueOrEmpty(harvester?.name)}</div>
          </div>
          <div className="kv-item">
            <div className="kv-label">Apiary Location</div>
            <div className="kv-value">{valueOrEmpty(harvester?.apiaryLocation)}</div>
          </div>
          <div className="kv-item">
            <div className="kv-label">Hive Code</div>
            <div className="kv-value mono">{valueOrEmpty(harvester?.hiveCode)}</div>
          </div>
          <div className="kv-item">
            <div className="kv-label">Bee Breed / Queen</div>
            <div className="kv-value">{valueOrEmpty(harvester?.beeBreed)} ({valueOrEmpty(harvester?.queenStatus)})</div>
          </div>
        </div>
      </div>
    </motion.div>
  );
};
