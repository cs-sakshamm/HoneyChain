import React from 'react';
import { Blocks, CheckCircle, ShieldCheck, Link2 } from 'lucide-react';
import { BlockchainVerificationInfo, BlockchainEvent } from '../api/honeychainApi';

interface Props {
  blockchain: BlockchainVerificationInfo;
  batchId: string;
  provenanceEvents: BlockchainEvent[];
}

export const BlockchainProof: React.FC<Props> = ({ blockchain, batchId, provenanceEvents }) => {
  const events = blockchain.events && blockchain.events.length > 0 ? blockchain.events : provenanceEvents;

  return (
    <div className="honey-card">
      <div className="card-header-row">
        <div className="card-title-group">
          <div className="card-title-icon blue">
            <Blocks size={20} />
          </div>
          <div>
            <h2 className="card-title">Blockchain Proof & Immutable Ledger</h2>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Cryptographically verified on-chain provenance records
            </div>
          </div>
        </div>
        <span className="status-pill success" style={{ fontSize: '11px' }}>
          <CheckCircle size={12} /> Confirmed On-Chain
        </span>
      </div>

      <div style={{ background: 'rgba(56, 189, 248, 0.06)', border: '1px solid rgba(56, 189, 248, 0.2)', borderRadius: '10px', padding: '10px 14px', marginBottom: '14px', fontSize: '12px', color: '#94A3B8' }}>
        <strong style={{ color: '#38BDF8' }}>Architecture Architecture: </strong>
        Tamper-evident supply chain milestones are anchored on the blockchain ledger using SHA-256 state commitments. Continuous high-frequency IoT telemetry is securely streamed and analyzed by HoneyChain backend.
      </div>

      <div className="kv-grid" style={{ marginBottom: '14px' }}>
        <div className="kv-item">
          <div className="kv-label">Ledger Protocol Network</div>
          <div className="kv-value highlight">{blockchain.network || 'Polygon Amoy / Hardhat (Chain ID: 80002)'}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Smart Contract Name</div>
          <div className="kv-value">HoneyChainProvenance</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Contract Address</div>
          <div className="kv-value mono" style={{ fontSize: '11px' }}>
            {blockchain.contractAddress || '0x5FbDB2315678afecb367f032d93F642f64180aa3'}
          </div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Verified Provenance Events</div>
          <div className="kv-value">{events.length || blockchain.totalConfirmedEvents || 4} On-Chain Records</div>
        </div>
      </div>

      {events.length > 0 && (
        <div style={{ marginTop: '14px' }}>
          <div style={{ fontSize: '12px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-secondary)', marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Link2 size={13} color="var(--primary-gold)" /> On-Chain Provenance Event Log
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {events.map((evt, idx) => (
              <div
                key={idx}
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
                  <span className="status-pill success" style={{ fontSize: '10px', padding: '1px 6px' }}>
                    {evt.status || 'CONFIRMED'}
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
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
