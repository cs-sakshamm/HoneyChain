import React, { useState } from 'react';
import { Cpu, Thermometer, Droplets, Scale, Activity, Battery, ChevronDown, ChevronUp } from 'lucide-react';
import { IoTTelemetryInfo } from '../api/honeychainApi';

interface Props {
  telemetry: IoTTelemetryInfo | null;
}

export const IoTTelemetry: React.FC<Props> = ({ telemetry }) => {
  const [showTechnical, setShowTechnical] = useState(false);

  if (!telemetry) {
    return (
      <div className="honey-card">
        <div className="card-header-row">
          <div className="card-title-group">
            <div className="card-title-icon">
              <Cpu size={20} />
            </div>
            <div>
              <h2 className="card-title">Hive IoT Telemetry & Sensor Readings</h2>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Real-time apiary sensory monitoring</div>
            </div>
          </div>
        </div>
        <p style={{ color: 'var(--text-muted)', fontStyle: 'italic', fontSize: '13px' }}>
          No telemetry records found for this batch's hive.
        </p>
      </div>
    );
  }

  return (
    <div className="honey-card">
      <div className="card-header-row">
        <div className="card-title-group">
          <div className="card-title-icon">
            <Cpu size={20} />
          </div>
          <div>
            <h2 className="card-title">Hive IoT Telemetry & Sensor Readings</h2>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Hardware ESP32 edge stream • Telemetry stored and analyzed by HoneyChain
            </div>
          </div>
        </div>
        <span className="status-pill success" style={{ fontSize: '11px' }}>
          Live Sensors
        </span>
      </div>

      <div className="kv-grid" style={{ marginBottom: '14px' }}>
        <div className="kv-item">
          <div className="kv-label" style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <Thermometer size={12} color="#F59E0B" /> Temperature
          </div>
          <div className="kv-value highlight">{telemetry.temperature}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label" style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <Droplets size={12} color="#38BDF8" /> Humidity
          </div>
          <div className="kv-value">{telemetry.humidity}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label" style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <Scale size={12} color="#10B981" /> Colony Weight
          </div>
          <div className="kv-value">{telemetry.weight}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label" style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <Activity size={12} color="#A78BFA" /> Acoustics Frequency
          </div>
          <div className="kv-value">{telemetry.acoustics}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label" style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <Battery size={12} color="#FBBF24" /> Battery Voltage
          </div>
          <div className="kv-value">{telemetry.battery}</div>
        </div>
        <div className="kv-item">
          <div className="kv-label">Recorded At</div>
          <div className="kv-value" style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
            {new Date(telemetry.recordedAt).toLocaleString()}
          </div>
        </div>
      </div>

      <button
        onClick={() => setShowTechnical(!showTechnical)}
        className="btn-secondary"
        style={{ width: '100%', marginTop: '4px' }}
      >
        {showTechnical ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
        {showTechnical ? 'Hide Technical Data' : 'View Technical Data (JSON)'}
      </button>

      {showTechnical && (
        <pre
          style={{
            marginTop: '10px',
            background: 'rgba(0, 0, 0, 0.4)',
            padding: '12px',
            borderRadius: '8px',
            fontSize: '11px',
            fontFamily: 'var(--font-mono)',
            color: '#CBD5E1',
            overflowX: 'auto',
          }}
        >
          {JSON.stringify(telemetry, null, 2)}
        </pre>
      )}
    </div>
  );
};
