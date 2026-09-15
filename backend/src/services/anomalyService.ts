import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export interface TelemetryPayload {
  hiveId: string;
  hiveCode?: string;
  temperature: number;
  humidity: number;
  weightKg: number;
  beeActivity: number;
  soundFrequencyHz?: number;
  batteryLevel?: number;
  signalStrength?: number;
  timestamp?: string | Date;
}

export interface AnomalyDetectionResult {
  isCritical: boolean;
  alerts: Array<{
    parameter: string;
    previousValue: string;
    currentValue: string;
    changeValue: string;
    unit: string;
    severity: 'CRITICAL' | 'WARNING';
    message: string;
  }>;
}

export const THRESHOLDS = {
  temperature: {
    suddenChangeDelta: 4.0,
    minNormal: 30.0,
    maxNormal: 37.0,
    unit: '°C'
  },
  humidity: {
    suddenChangeDelta: 15.0,
    minNormal: 45.0,
    maxNormal: 75.0,
    unit: '%'
  },
  weightKg: {
    suddenChangeDelta: 2.0,
    unit: 'kg'
  },
  beeActivity: {
    suddenChangeDelta: 30.0,
    minNormal: 20.0,
    unit: '%'
  },
  soundFrequencyHz: {
    suddenChangeDelta: 120.0,
    unit: 'Hz'
  }
};

export class AnomalyDetectionService {
  async evaluateTelemetry(payload: TelemetryPayload): Promise<AnomalyDetectionResult> {
    const alerts: AnomalyDetectionResult['alerts'] = [];

    const lastTelemetry = await prisma.hiveTelemetry.findFirst({
      where: { hiveId: payload.hiveId },
      orderBy: { recordedAt: 'desc' }
    });

    if (lastTelemetry) {
      const tempDelta = Number((payload.temperature - lastTelemetry.temperature).toFixed(1));
      if (Math.abs(tempDelta) >= THRESHOLDS.temperature.suddenChangeDelta ||
          payload.temperature > THRESHOLDS.temperature.maxNormal ||
          payload.temperature < THRESHOLDS.temperature.minNormal) {
        
        const sign = tempDelta > 0 ? ('+' + tempDelta) : ('' + tempDelta);
        alerts.push({
          parameter: 'Temperature',
          previousValue: lastTelemetry.temperature.toFixed(1) + '°C',
          currentValue: payload.temperature.toFixed(1) + '°C',
          changeValue: sign + '°C',
          unit: '°C',
          severity: 'CRITICAL',
          message: 'Sudden temperature shift of ' + sign + '°C detected in hive.'
        });
      }

      const humDelta = Number((payload.humidity - lastTelemetry.humidity).toFixed(1));
      if (Math.abs(humDelta) >= THRESHOLDS.humidity.suddenChangeDelta ||
          payload.humidity > THRESHOLDS.humidity.maxNormal ||
          payload.humidity < THRESHOLDS.humidity.minNormal) {
        
        const sign = humDelta > 0 ? ('+' + humDelta) : ('' + humDelta);
        alerts.push({
          parameter: 'Humidity',
          previousValue: lastTelemetry.humidity.toFixed(1) + '%',
          currentValue: payload.humidity.toFixed(1) + '%',
          changeValue: sign + '%',
          unit: '%',
          severity: 'CRITICAL',
          message: 'Sudden internal humidity shift of ' + sign + '% detected.'
        });
      }

      const weightDelta = Number((payload.weightKg - lastTelemetry.weightKg).toFixed(1));
      if (Math.abs(weightDelta) >= THRESHOLDS.weightKg.suddenChangeDelta) {
        const sign = weightDelta > 0 ? ('+' + weightDelta) : ('' + weightDelta);
        alerts.push({
          parameter: 'Hive weight',
          previousValue: lastTelemetry.weightKg.toFixed(1) + ' kg',
          currentValue: payload.weightKg.toFixed(1) + ' kg',
          changeValue: sign + ' kg',
          unit: 'kg',
          severity: 'CRITICAL',
          message: 'Sudden hive weight shift of ' + sign + ' kg detected.'
        });
      }

      const activityDelta = Number((payload.beeActivity - lastTelemetry.beeActivity).toFixed(1));
      if (Math.abs(activityDelta) >= THRESHOLDS.beeActivity.suddenChangeDelta ||
          payload.beeActivity < THRESHOLDS.beeActivity.minNormal) {
        const sign = activityDelta > 0 ? ('+' + activityDelta) : ('' + activityDelta);
        alerts.push({
          parameter: 'Bee activity',
          previousValue: lastTelemetry.beeActivity.toFixed(1) + '%',
          currentValue: payload.beeActivity.toFixed(1) + '%',
          changeValue: sign + '%',
          unit: '%',
          severity: 'CRITICAL',
          message: 'Abnormal bee activity delta of ' + sign + '% detected.'
        });
      }

      if (payload.soundFrequencyHz && lastTelemetry.soundFrequencyHz) {
        const freqDelta = Number((payload.soundFrequencyHz - lastTelemetry.soundFrequencyHz).toFixed(1));
        if (Math.abs(freqDelta) >= THRESHOLDS.soundFrequencyHz.suddenChangeDelta) {
          const sign = freqDelta > 0 ? ('+' + freqDelta) : ('' + freqDelta);
          alerts.push({
            parameter: 'Sound Frequency',
            previousValue: lastTelemetry.soundFrequencyHz.toFixed(1) + ' Hz',
            currentValue: payload.soundFrequencyHz.toFixed(1) + ' Hz',
            changeValue: sign + ' Hz',
            unit: 'Hz',
            severity: 'CRITICAL',
            message: 'Acoustic frequency jump of ' + sign + ' Hz detected.'
          });
        }
      }
    }

    return {
      isCritical: alerts.some((a) => a.severity === 'CRITICAL'),
      alerts
    };
  }
}

export const anomalyService = new AnomalyDetectionService();