import { PrismaClient } from '@prisma/client';
import { anomalyService } from './services/anomalyService';

const prisma = new PrismaClient();

async function runE2ETelemetryAlertTests() {
  console.log('🧪 Starting Harvester Telemetry & Sudden Change Alert E2E Test Suite...\n');

  try {
    const user = await prisma.user.upsert({
      where: {
        email_role: {
          email: 'maria.harvester@honeychain.io',
          role: 'HARVESTER'
        }
      },
      update: {},
      create: {
        name: 'Maria Santos',
        email: 'maria.harvester@honeychain.io',
        role: 'HARVESTER'
      }
    });

    const hive = await prisma.hive.upsert({
      where: { hiveCode: 'HIVE-CRIT-001' },
      update: {},
      create: {
        userId: user.id,
        name: 'Alpha Apiary Hive 1',
        hiveCode: 'HIVE-CRIT-001',
        apiaryLocation: 'Meadow Apiary Block A',
        hiveType: 'Langstroth',
        queenStatus: 'Mated',
        overallHealth: 'Healthy'
      }
    });

    console.log(`📌 Test Hive Initialized: ${hive.name} (${hive.hiveCode})`);

    await prisma.hiveAlert.deleteMany({ where: { hiveId: hive.id } });
    await prisma.hiveTelemetry.deleteMany({ where: { hiveId: hive.id } });

    console.log('--- 1. Ingesting Normal Baseline Telemetry (32.4°C, 62% humidity, 24.5 kg weight) ---');
    await prisma.hiveTelemetry.create({
      data: {
        hiveId: hive.id,
        hiveCode: hive.hiveCode,
        temperature: 32.4,
        humidity: 62.0,
        weightKg: 24.5,
        beeActivity: 88.0,
        soundFrequencyHz: 230.0,
        recordedAt: new Date(Date.now() - 60000)
      }
    });
    console.log('  ✅ Baseline telemetry recorded successfully.');

    console.log('\n--- 2. Ingesting Sudden Temperature Jump Telemetry (39.8°C) ---');
    const incomingPayload = {
      hiveId: hive.id,
      hiveCode: hive.hiveCode,
      temperature: 39.8,
      humidity: 61.5,
      weightKg: 24.4,
      beeActivity: 85.0,
      soundFrequencyHz: 235.0
    };

    const anomalyResult = await anomalyService.evaluateTelemetry(incomingPayload);
    console.log(`  Anomaly evaluation: isCritical=${anomalyResult.isCritical}, alertsCount=${anomalyResult.alerts.length}`);

    if (!anomalyResult.isCritical || anomalyResult.alerts.length === 0) {
      throw new Error('FAIL: Anomaly detection failed to flag sudden +7.4°C temperature jump as CRITICAL');
    }

    const tempAlert = anomalyResult.alerts.find(a => a.parameter === 'Temperature');
    if (!tempAlert) {
      throw new Error('FAIL: Temperature alert missing in anomaly evaluation');
    }

    console.log(`  Alert details: Parameter=${tempAlert.parameter}, Prev=${tempAlert.previousValue}, Curr=${tempAlert.currentValue}, Change=${tempAlert.changeValue}`);
    if (tempAlert.previousValue !== '32.4°C' || tempAlert.currentValue !== '39.8°C' || tempAlert.changeValue !== '+7.4°C') {
      throw new Error(`FAIL: Unexpected alert values: ${JSON.stringify(tempAlert)}`);
    }
    console.log('  ✅ PASS: Sudden temperature jump (+7.4°C) flagged with exact delta values.');

    const createdAlert = await prisma.hiveAlert.create({
      data: {
        hiveId: hive.id,
        hiveCode: hive.hiveCode,
        parameter: tempAlert.parameter,
        previousValue: tempAlert.previousValue,
        currentValue: tempAlert.currentValue,
        changeValue: tempAlert.changeValue,
        unit: tempAlert.unit,
        severity: tempAlert.severity,
        message: tempAlert.message,
        status: 'ACTIVE'
      }
    });

    console.log(`\n--- 3. Alert Created & Active: ID=${createdAlert.id} ---`);

    console.log('\n--- 4. Harvester Acknowledges Alert (Pressing OK) ---');
    const acknowledgedAlert = await prisma.hiveAlert.update({
      where: { id: createdAlert.id },
      data: {
        status: 'ACKNOWLEDGED',
        acknowledgedAt: new Date(),
        acknowledgedBy: 'Maria Santos (Harvester)'
      }
    });

    if (acknowledgedAlert.status !== 'ACKNOWLEDGED' || !acknowledgedAlert.acknowledgedAt) {
      throw new Error('FAIL: Alert acknowledgement failed to record status/timestamp');
    }
    console.log(`  ✅ PASS: Alert successfully acknowledged at ${acknowledgedAlert.acknowledgedAt.toISOString()} by ${acknowledgedAlert.acknowledgedBy}`);

    console.log('\n🎉 ALL 4/4 Telemetry Sudden Change & Critical Alert Tests PASSED Successfully!\n');
  } catch (error) {
    console.error('❌ Test suite failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

runE2ETelemetryAlertTests();