import React from 'react';
import { GitCommit, CheckCircle2, Clock } from 'lucide-react';
import { BlockchainEvent, HarvesterInfo, ProcessingInfo, LabVerificationInfo, PackagingInfoData } from '../api/honeychainApi';
import { motion, useReducedMotion } from 'framer-motion';
import { staggerContainer, getHoverProps } from '../utils/animations';

interface Props {
  harvester: HarvesterInfo;
  processing: ProcessingInfo | null;
  lab: LabVerificationInfo | null;
  packaging: PackagingInfoData | null;
  provenanceEvents: BlockchainEvent[];
}

const missing = 'Missing stage';
const valueOrMissing = (value: unknown) => {
  if (value === null || value === undefined || value === '') return missing;
  return String(value);
};

export const ProvenanceTimeline: React.FC<Props> = ({
  harvester,
  processing,
  lab,
  packaging,
  provenanceEvents,
}) => {
  const shouldReduceMotion = useReducedMotion();
  const hoverProps = getHoverProps(shouldReduceMotion ?? false);

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
      title: 'Harvest',
      actor: valueOrMissing(harvester?.name),
      details: `Hive: ${valueOrMissing(harvester?.hiveCode)} | Location: ${valueOrMissing(harvester?.apiaryLocation)}`,
      timestamp: harvestEvt?.timestamp,
      dataHash: harvestEvt?.dataHash,
      complete: Boolean(harvestEvt),
    },
    {
      num: '02',
      title: 'Collection & Processing',
      actor: valueOrMissing(processing?.processor),
      details: `Method: ${valueOrMissing(processing?.method)} | Quantity received: ${valueOrMissing(processing?.quantityReceivedKg)} kg`,
      timestamp: processEvt?.timestamp,
      dataHash: processEvt?.dataHash,
      complete: Boolean(processing && processEvt),
    },
    {
      num: '03',
      title: 'Lab Test',
      actor: valueOrMissing(lab?.labName),
      details: `Report: ${valueOrMissing(lab?.reportId)} | Status: ${valueOrMissing(lab?.status)}`,
      timestamp: labEvt?.timestamp,
      dataHash: labEvt?.dataHash,
      complete: Boolean(lab && labEvt),
    },
    {
      num: '04',
      title: 'Packaging',
      actor: valueOrMissing(packaging?.facility),
      details: `${valueOrMissing(packaging?.numberOfPackages)} units | Format: ${valueOrMissing(packaging?.packageSize)}`,
      timestamp: packaging?.packagingDate || packEvt?.timestamp,
      dataHash: packEvt?.dataHash,
      complete: Boolean(packaging && packEvt),
    },
  ];

  const nodeVariants = {
    hidden: { opacity: 0, x: -10 },
    visible: { opacity: 1, x: 0, transition: { duration: 0.3 } }
  };

  const reducedNodeVariants = {
    hidden: { opacity: 0 },
    visible: { opacity: 1, transition: { duration: 0.3 } }
  };

  return (
    <motion.div className="honey-card" {...hoverProps}>
      <div className="card-header-row">
        <div className="card-title-group">
          <div className="card-title-icon">
            <GitCommit size={20} />
          </div>
          <div>
            <h2 className="card-title">Full Traceability History</h2>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Chronological tamper-evident supply-chain events
            </div>
          </div>
        </div>
      </div>

      <motion.div
        className="timeline-list"
        variants={staggerContainer}
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-50px" }}
      >
        {stages.map((stage) => (
          <motion.div
            key={stage.num}
            className={`timeline-node ${stage.complete ? 'active' : ''}`}
            variants={shouldReduceMotion ? reducedNodeVariants : nodeVariants}
          >
            <motion.div
              className="timeline-dot"
              initial={{ scale: 0 }}
              whileInView={{ scale: 1 }}
              viewport={{ once: true }}
              transition={{ delay: 0.1, type: 'spring', stiffness: 200, damping: 10 }}
            >
              {stage.complete ? <CheckCircle2 size={14} /> : <Clock size={14} />}
            </motion.div>
            <div className="timeline-node-content">
              <div className="timeline-stage-title">
                <span>{stage.num}. {stage.title}</span>
                <span className={`status-pill ${stage.complete ? 'success' : 'gold'}`} style={{ fontSize: '10px', padding: '2px 8px' }}>
                  {stage.complete ? 'Recorded' : 'Missing'}
                </span>
              </div>
              <div className="timeline-stage-actor">{stage.actor}</div>
              <div className="timeline-stage-details">{stage.details}</div>
              {stage.timestamp && (
                <div className="timeline-stage-details">{new Date(stage.timestamp).toLocaleString()}</div>
              )}
              {stage.dataHash && (
                <div style={{ marginTop: '6px', fontSize: '11px', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', wordBreak: 'break-all' }}>
                  <span style={{ color: 'var(--text-secondary)' }}>Data Hash: </span>
                  {stage.dataHash.substring(0, 24)}...
                </div>
              )}
            </div>
          </motion.div>
        ))}
      </motion.div>
    </motion.div>
  );
};
