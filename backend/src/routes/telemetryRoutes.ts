import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { anomalyService, TelemetryPayload } from '../services/anomalyService';

const router = Router();
const prisma = new PrismaClient();

/**
 * POST /api/telemetry/ingest
 * Ingest live JSON sensor stream from ESP32 / Gateway / Simulator
 * Automatically detects sudden parameter changes and creates critical alerts.
 */
router.post('/ingest', async (req: Request, res: Response) => {
  try {
    const data = req.body as TelemetryPayload;

    if (!data.hiveId || data.temperature === undefined || data.humidity === undefined || data.weightKg === undefined) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_PAYLOAD',
        message: 'hiveId, temperature, humidity, and weightKg are required.'
      });
    }

    // Resolve Hive to verify existence
    const hive = await prisma.hive.findFirst({
      where: {
        OR: [
          { id: data.hiveId },
          { hiveCode: data.hiveId }
        ]
      }
    });

    if (!hive) {
      return res.status(404).json({
        success: false,
        error: 'HIVE_NOT_FOUND',
        message: Hive with ID/Code  not found.
      });
    }

    const effectiveHiveId = hive.id;
    const effectiveHiveCode = hive.hiveCode;

    // 1. Run real-time Sudden Change & Anomaly Detection against previous recorded payload
    const evalResult = await anomalyService.evaluateTelemetry({
      ...data,
      hiveId: effectiveHiveId,
      hiveCode: effectiveHiveCode
    });

    // 2. Persist newly ingested telemetry record
    const telemetry = await prisma.hiveTelemetry.create({
      data: {
        hiveId: effectiveHiveId,
        hiveCode: effectiveHiveCode,
        temperature: Number(data.temperature),
        humidity: Number(data.humidity),
        weightKg: Number(data.weightKg),
        beeActivity: Number(data.beeActivity ?? 85.0),
        soundFrequencyHz: data.soundFrequencyHz !== undefined ? Number(data.soundFrequencyHz) : null,
        batteryLevel: data.batteryLevel !== undefined ? Number(data.batteryLevel) : 100.0,
        signalStrength: data.signalStrength !== undefined ? Number(data.signalStrength) : -65.0,
        recordedAt: data.timestamp ? new Date(data.timestamp) : new Date()
      }
    });

    // 3. If critical sudden changes are detected, create unignorable HiveAlert records
    const createdAlerts = [];
    if (evalResult.alerts.length > 0) {
      for (const alertData of evalResult.alerts) {
        // Prevent duplicate spamming of identical alerts within a 2-minute window if already ACTIVE
        const recentDuplicate = await prisma.hiveAlert.findFirst({
          where: {
            hiveId: effectiveHiveId,
            parameter: alertData.parameter,
            status: 'ACTIVE',
            createdAt: {
              gte: new Date(Date.now() - 2 * 60 * 1000)
            }
          }
        });

        if (!recentDuplicate) {
          const alert = await prisma.hiveAlert.create({
            data: {
              hiveId: effectiveHiveId,
              hiveCode: effectiveHiveCode,
              parameter: alertData.parameter,
              previousValue: alertData.previousValue,
              currentValue: alertData.currentValue,
              changeValue: alertData.changeValue,
              unit: alertData.unit,
              severity: alertData.severity,
              message: alertData.message,
              status: 'ACTIVE',
              detectedAt: new Date()
            }
          });
          createdAlerts.push(alert);
        }
      }
    }

    res.status(201).json({
      success: true,
      telemetryId: telemetry.id,
      hiveCode: effectiveHiveCode,
      hasCriticalAlert: evalResult.isCritical,
      alertsCreated: createdAlerts.length,
      alerts: createdAlerts,
      recordedAt: telemetry.recordedAt
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * GET /api/telemetry/alerts
 * Fetch active and recent critical alerts for a user's hives
 */
router.get('/alerts', async (req: Request, res: Response) => {
  try {
    const { userId, hiveId, status } = req.query;

    const whereClause: any = {};
    if (status) {
      whereClause.status = String(status);
    }
    if (hiveId) {
      whereClause.hiveId = String(hiveId);
    } else if (userId) {
      // Find all hives owned by this user
      const userHives = await prisma.hive.findMany({
        where: {
          OR: [
            { userId: String(userId) },
            { user: { email: String(userId).toLowerCase() } }
          ]
        },
        select: { id: true }
      });
      const hiveIds = userHives.map((h) => h.id);
      whereClause.hiveId = { in: hiveIds };
    }

    const alerts = await prisma.hiveAlert.findMany({
      where: whereClause,
      orderBy: { detectedAt: 'desc' },
      take: 20
    });

    res.json({
      success: true,
      count: alerts.length,
      alerts
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/telemetry/alerts/:id/acknowledge
 * Acknowledge an alert when Harvester clicks [ OK ]
 */
router.post('/alerts/:id/acknowledge', async (req: Request, res: Response) => {
  try {
    const alertId = req.params.id;
    const { userId, userName } = req.body;

    const alert = await prisma.hiveAlert.findUnique({
      where: { id: alertId }
    });

    if (!alert) {
      return res.status(404).json({ success: false, error: 'Alert not found' });
    }

    const acknowledged = await prisma.hiveAlert.update({
      where: { id: alertId },
      data: {
        status: 'ACKNOWLEDGED',
        acknowledgedAt: new Date(),
        acknowledgedBy: userName || userId || 'Harvester'
      }
    });

    res.json({
      success: true,
      message: 'Alert acknowledged successfully.',
      alert: acknowledged
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * GET /api/telemetry/live/:hiveId
 * Fetch recent telemetry stream history for a specific hive
 */
router.get('/live/:hiveId', async (req: Request, res: Response) => {
  try {
    const hiveId = req.params.hiveId;
    const telemetry = await prisma.hiveTelemetry.findMany({
      where: {
        OR: [
          { hiveId: hiveId },
          { hiveCode: hiveId }
        ]
      },
      orderBy: { recordedAt: 'desc' },
      take: 50
    });

    res.json({
      success: true,
      hiveId,
      count: telemetry.length,
      telemetry
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

export default router;
