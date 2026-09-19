import React from 'react';
import { Sparkles, CheckCircle, AlertTriangle } from 'lucide-react';
import { AIAnalysisInfo } from '../api/honeychainApi';
import { motion, useReducedMotion } from 'framer-motion';
import { getHoverProps } from '../utils/animations';

interface Props {
  ai: AIAnalysisInfo | null;
}

export const AIAnalysis: React.FC<Props> = ({ ai }) => {
  const shouldReduceMotion = useReducedMotion();
  const hoverProps = getHoverProps(shouldReduceMotion ?? false);

  if (!ai) {
    return (
      <motion.div className="honey-card" {...hoverProps}>
        <div className="card-header-row">
          <div className="card-title-group">
            <div className="card-title-icon">
              <Sparkles size={20} />
            </div>
            <div>
              <h2 className="card-title">AI Hive Colony Health & Anomaly Analysis</h2>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Continuous machine learning health evaluation</div>
            </div>
          </div>
        </div>
        <p style={{ color: 'var(--text-muted)', fontStyle: 'italic', fontSize: '13px' }}>
          No AI/ML inference records available for this batch.
        </p>
      </motion.div>
    );
  }

  const isHealthy = ai.healthStatus.toUpperCase().includes('HEALTH') || ai.riskLevel.toUpperCase().includes('LOW');

  return (
    <motion.div className="honey-card" {...hoverProps}>
      <div className="card-header-row">
        <div className="card-title-group">
          <div className={`card-title-icon ${isHealthy ? 'success' : ''}`}>
            <Sparkles size={20} />
          </div>
          <div>
            <h2 className="card-title">AI Hive Colony Health & Anomaly Analysis</h2>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Isolation Forest ML inference model • HoneyChain predictive engine
            </div>
          </div>
        </div>
        <span className={`status-pill ${isHealthy ? 'success' : 'gold'}`}>
          {isHealthy ? <CheckCircle size={12} /> : <AlertTriangle size={12} />}
          {ai.healthStatus}
        </span>
      </div>

      <div className="kv-grid" style={{ marginBottom: '14px' }}>
        <div className="kv-item">
          <div className="kv-label">Swarm & Health Risk</div>
          <div className="kv-value highlight">{ai.riskLevel}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Anomaly Score</div>
          <div className="kv-value mono">
            {typeof ai.anomalyScore === 'number' ? ai.anomalyScore.toFixed(4) : ai.anomalyScore}
          </div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Thermal Microclimate</div>
          <div className="kv-value">{ai.temperatureStatus}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Relative Humidity Trend</div>
          <div className="kv-value">{ai.humidityStatus}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Colony Weight Stability</div>
          <div className="kv-value">{ai.weightStatus}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Acoustics Queen Signature</div>
          <div className="kv-value">{ai.acousticStatus}</div>
        </div>
      </div>

      <div style={{ fontSize: '11px', color: 'var(--text-muted)', fontStyle: 'italic', borderTop: '1px solid var(--border-subtle)', paddingTop: '8px' }}>
        Note: AI inference is an environmental monitoring and anomaly detection assessment, not an official laboratory purity certificate.
      </div>
    </motion.div>
  );
};
