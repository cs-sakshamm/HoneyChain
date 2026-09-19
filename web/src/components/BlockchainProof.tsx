import React from 'react';
import { Blocks, CheckCircle, Clock, Link2 } from 'lucide-react';
import { BlockchainVerificationInfo, BlockchainEvent } from '../api/honeychainApi';
import { motion, useReducedMotion } from 'framer-motion';
import { staggerContainer, getHoverProps } from '../utils/animations';

interface Props {
  blockchain: BlockchainVerificationInfo;
  batchId: string;
  provenanceEvents: BlockchainEvent[];
}

export const BlockchainProof: React.FC<Props> = ({ blockchain, provenanceEvents }) => {
  const shouldReduceMotion = useReducedMotion();
  const hoverProps = getHoverProps(shouldReduceMotion ?? false);
  const events = blockchain.events && blockchain.events.length > 0 ? blockchain.events : provenanceEvents;
  const hasEvents = events.length > 0;

  const eventItemVariants = {
    hidden: { opacity: 0, y: 5 },
    visible: { opacity: 1, y: 0, transition: { duration: 0.2 } }
  };

  const reducedEventItemVariants = {
    hidden: { opacity: 0 },
    visible: { opacity: 1, transition: { duration: 0.2 } }
  };

  return (
    <motion.div className="honey-card" {...hoverProps}>
      <div className="card-header-row">
        <div className="card-title-group">
          <div className={`card-title-icon ${hasEvents ? 'blue' : ''}`}>
            <Blocks size={20} />
          </div>
          <div>
            <h2 className="card-title">Blockchain Proof & Tamper-Evident Ledger</h2>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Authorized supply-chain events and document hashes anchored as state commitments
            </div>
          </div>
        </div>
        <span className={`status-pill ${hasEvents ? 'success' : 'gold'}`} style={{ fontSize: '11px' }}>
          {hasEvents ? <CheckCircle size={12} /> : <Clock size={12} />} {hasEvents ? 'Events Recorded' : 'No Records Yet'}
        </span>
      </div>

      <div style={{ background: 'rgba(56, 189, 248, 0.06)', border: '1px solid rgba(56, 189, 248, 0.2)', borderRadius: '10px', padding: '10px 14px', marginBottom: '14px', fontSize: '12px', color: '#94A3B8' }}>
        <strong style={{ color: '#38BDF8' }}>Traceability note: </strong>
        HoneyChain verifies authorization, ordering, and tamper-evident integrity of recorded events and documents. It does not independently prove every physical-world value is truthful.
      </div>

      <div className="kv-grid" style={{ marginBottom: '14px' }}>
        <div className="kv-item">
          <div className="kv-label">Ledger Network</div>
          <div className="kv-value highlight">{blockchain.network || 'Not configured'}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Smart Contract</div>
          <div className="kv-value">HoneyChainProvenance</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Contract Address</div>
          <div className="kv-value mono" style={{ fontSize: '11px' }}>
            {blockchain.contractAddress || 'Not configured'}
          </div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Provenance Events</div>
          <div className="kv-value">{events.length || blockchain.totalConfirmedEvents || 0} Records</div>
        </div>
      </div>

      {hasEvents ? (
        <div style={{ marginTop: '14px' }}>
          <div style={{ fontSize: '12px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-secondary)', marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Link2 size={13} color="var(--primary-gold)" /> Provenance Event Log
          </div>
          <motion.div
            style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}
            variants={staggerContainer}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-20px" }}
          >
            {events.map((evt, idx) => (
              <motion.div
                key={idx}
                variants={shouldReduceMotion ? reducedEventItemVariants : eventItemVariants}
                style={{
                  background: 'rgba(15, 23, 42, 0.6)',
                  border: '1px solid var(--border-subtle)',
                  borderRadius: '8px',
                  padding: '10px 12px',
                  fontSize: '12px',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4px' }}>
                  <span style={{ fontWeight: 600, color: 'var(--primary-gold)' }}>{evt.eventType}</span>
                  <span className={`status-pill ${evt.status === 'FAILED' ? 'danger' : 'success'}`} style={{ fontSize: '10px', padding: '1px 6px' }}>
                    {evt.status || 'RECORDED'}
                  </span>
                </div>
                <div style={{ color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', fontSize: '11px', wordBreak: 'break-all' }}>
                  <span style={{ color: 'var(--text-secondary)' }}>Data Hash: </span>
                  {evt.dataHash}
                </div>
                {evt.txHash && (
                  <div style={{ color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', fontSize: '11px', marginTop: '2px', wordBreak: 'break-all' }}>
                    <span style={{ color: 'var(--text-secondary)' }}>Tx Hash: </span>
                    {evt.txHash}
                  </div>
                )}
              </motion.div>
            ))}
          </motion.div>
        </div>
      ) : (
        <p style={{ color: 'var(--text-muted)', fontStyle: 'italic', fontSize: '13px' }}>
          No blockchain provenance events have been recorded for this batch.
        </p>
      )}
    </motion.div>
  );
};
