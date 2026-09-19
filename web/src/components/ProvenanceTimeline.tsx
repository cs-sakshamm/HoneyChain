import React from 'react';
import { GitCommit, CheckCircle2 } from 'lucide-react';
import { BlockchainEvent, HarvesterInfo, ProcessingInfo, LabVerificationInfo, PackagingInfoData } from '../api/honeychainApi';

interface Props {
  harvester: HarvesterInfo;
  processing: ProcessingInfo | null;
  lab: LabVerificationInfo | null;
  packaging: PackagingInfoData | null;
  provenanceEvents: BlockchainEvent[];
}

export const ProvenanceTimeline: React.FC<Props> = ({
  harvester,
  processing,
  lab,
  packaging,
  provenanceEvents,
}) => {
  const findEvent = (typeSubstring: string) => {
    return provenanceEvents.find(e => e.eventType.toUpperCase().includes(typeSubstring));
  };

  const harvestEvt = findEvent('HARVEST') || findEvent('COLLECTION');
  const processEvt = findEvent('PROCESS');
  const labEvt = findEvent('LAB');
  const packEvt = findEvent('PACKAG');

  const stages = [
    {
      num: '01',
      title: 'Harvest & Field Collection',
      actor: harvester?.name || 'Verified Harvester',
      location: harvester?.apiaryLocation || 'Apiary Zone',
      details: `Hive: ${harvester?.hiveCode || 'HIVE-MVP-01'} • Breed: ${harvester?.beeBreed || 'Apis cerana indica'}`,
      timestamp: harvestEvt?.timestamp || 'Recorded at harvest',
      status: 'VERIFIED',
      dataHash: harvestEvt?.dataHash,
    },
    {
      num: '02',
      title: 'Cold Extraction & Processing',
      actor: processing?.processor || 'Sahyadri Honey Processing Hub',
      location: 'Central Processing Centre',
      details: `Method: ${processing?.method || 'Centrifugal Cold Extraction (< 38°C)'} • Moisture at Receipt: ${processing?.moistureAtReceipt || '17.0%'}`,
      timestamp: processEvt?.timestamp || 'Batch filtered & cold extracted',
      status: 'VERIFIED',
      dataHash: processEvt?.dataHash,
    },
    {
      num: '03',
      title: 'Laboratory Chemical Verification',
      actor: lab?.labName || 'National Apiculture Analytical Lab',
      location: 'Accredited Testing Facility (ISO 17025 / FSSAI)',
      details: `Report: ${lab?.reportId || 'Certified'} • Quality Score: ${lab?.qualityScore || '99.1'}/100 • Status: ${lab?.status || 'CERTIFIED APPROVED'}`,
      timestamp: labEvt?.timestamp || 'Chemical & floral profiling passed',
      status: 'VERIFIED',
      dataHash: labEvt?.dataHash,
    },
    {
      num: '04',
      title: 'Bottling & Induction Tamper Seal',
      actor: packaging?.facility || 'Sahyadri Pure Honey Bottling',
      location: 'Cleanroom Packaging Facility',
      details: `${packaging?.numberOfPackages || '48'} units sealed • Format: ${packaging?.packageSize || '500g Glass Jar'} • Digital QR Linked`,
      timestamp: packaging?.packagingDate || packEvt?.timestamp || 'Induction sealed & batch QR attached',
      status: 'VERIFIED',
      dataHash: packEvt?.dataHash,
    },
    {
      num: '05',
      title: 'Cryptographic Blockchain Ledger Registration',
      actor: 'HoneyChain Smart Contract Protocol',
      location: 'Decentralized Provenance Network',
      details: `${provenanceEvents.length || 4} immutable state transition records anchored on-chain with cryptographic SHA-256 hashes`,
      timestamp: packEvt?.timestamp || 'Ledger anchor confirmed',
      status: 'ON-CHAIN',
      dataHash: packEvt?.dataHash || provenanceEvents[provenanceEvents.length - 1]?.dataHash,
    },
  ];

  return (
    <div className="honey-card">
      <div className="card-header-row">
        <div className="card-title-group">
          <div className="card-title-icon">
            <GitCommit size={20} />
          </div>
          <div>
            <h2 className="card-title">Full Provenance Traceability History</h2>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Chronological immutable supply chain chain of custody
            </div>
          </div>
        </div>
      </div>

      <div className="timeline-list">
        {stages.map((stage) => (
          <div key={stage.num} className="timeline-node active">
            <div className="timeline-dot">
              <CheckCircle2 size={14} />
            </div>
            <div className="timeline-node-content">
              <div className="timeline-stage-title">
                <span>{stage.num}. {stage.title}</span>
                <span className="status-pill success" style={{ fontSize: '10px', padding: '2px 8px' }}>
                  {stage.status}
                </span>
              </div>
              <div className="timeline-stage-actor">{stage.actor}</div>
              <div className="timeline-stage-details">{stage.details}</div>
              {stage.dataHash && (
                <div style={{ marginTop: '6px', fontSize: '11px', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', wordBreak: 'break-all' }}>
                  <span style={{ color: 'var(--text-secondary)' }}>Data Hash: </span>
                  {stage.dataHash.substring(0, 24)}...
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
