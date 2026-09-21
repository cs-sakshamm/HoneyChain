export interface ProductInfo {
  productId: string;
  productName: string;
  batchCode: string;
  quantityKg: number | string;
  numberOfPackages: number | string;
  packageSize: string;
  sealType: string;
}

export interface HarvesterInfo {
  name: string;
  beekeeperId: string;
  apiaryLocation: string;
  hiveCode: string;
  beeBreed: string;
  queenStatus: string;
}

export interface IoTTelemetryInfo {
  temperature: string;
  humidity: string;
  weight: string;
  acoustics: string;
  battery: string;
  recordedAt: string;
}

export interface AIAnalysisInfo {
  healthStatus: string;
  riskLevel: string;
  anomalyScore: number | string;
  temperatureStatus: string;
  humidityStatus: string;
  weightStatus: string;
  acousticStatus: string;
  analyzedAt: string;
}

export interface CollectionInfo {
  center: string;
  collector: string;
  receivedDate: string;
  quantityKg: number | string;
  status: string;
}

export interface ProcessingInfo {
  processor: string;
  processingDate?: string;
  method: string;
  inputQuantityKg?: number | string;
  outputQuantityKg?: number | string;
  quantityReceivedKg?: number | string;
  moistureAtReceipt?: string;
  status?: string;
}

export interface LabParameter {
  name: string;
  value: string;
  standard: string;
  status: string;
}

export interface LabVerificationInfo {
  labName: string;
  reportId: string;
  qualityScore: number | string;
  status: string;
  parameters: LabParameter[];
}

export interface PackagingInfoData {
  facility: string;
  packagingDate: string;
  sealStatus: string;
  numberOfPackages: number | string;
  packageSize: string;
}

export interface BlockchainEvent {
  eventType: string;
  dataHash: string;
  txHash: string | null;
  status: string;
  timestamp: string | null;
  network?: string;
}

export interface BlockchainVerificationInfo {
  network: string;
  contractAddress: string | null;
  onChainConfigured: boolean;
  onChainReadSuccess: boolean;
  onChainEventCount: number;
  onChainReadError?: string | null;
  ledgerStatus: string;
  totalConfirmedEvents: number;
  latestTxHash: string | null;
  events: BlockchainEvent[];
}

export interface VerificationResponse {
  success: boolean;
  found: boolean;
  batchId: string;
  traceabilityId: string;
  status: string;
  currentStage: string;
  isFullyVerified: boolean;
  verificationTimestamp: string;
  product: ProductInfo;
  harvester: HarvesterInfo;
  iotTelemetry: IoTTelemetryInfo | null;
  aiAnalysis: AIAnalysisInfo | null;
  collection: CollectionInfo | null;
  processing: ProcessingInfo | null;
  collectionProcessing: ProcessingInfo | null; // Keep for backward compatibility with real data
  labVerification: LabVerificationInfo | null;
  packaging: PackagingInfoData | null;
  blockchainVerification: BlockchainVerificationInfo;
  provenanceEvents: BlockchainEvent[];
  events: BlockchainEvent[];
}

const API_BASE = (import.meta.env.VITE_API_URL || import.meta.env.VITE_API_BASE_URL || '').replace(/\/$/, '');

export async function fetchVerificationData(batchId: string): Promise<VerificationResponse> {
  // --- DEMO FALLBACK FOR PROTOTYPE ---
  // If the batchId is specifically the demo ID, return the isolated demo record.
  if (batchId === 'HC-SIH-2026') {
    return {
      success: true,
      found: true,
      batchId: 'HC-SIH-2026',
      traceabilityId: 'HC-SIH-2026',
      status: 'Verified',
      currentStage: 'PACKAGING',
      isFullyVerified: true,
      verificationTimestamp: new Date().toISOString(),
      product: {
        productId: 'PROD-001',
        productName: 'Raw Forest Honey',
        batchCode: 'HC-SIH-2026',
        quantityKg: 100,
        numberOfPackages: 200,
        packageSize: '500g',
        sealType: 'Tamper-Evident NFC'
      },
      harvester: {
        name: 'Tribal Co-op Harvesters',
        beekeeperId: 'BK-7389',
        apiaryLocation: 'Nilgiris Biosphere Reserve',
        hiveCode: 'HIVE-802',
        beeBreed: 'Apis Cerana',
        queenStatus: 'Active'
      },
      iotTelemetry: {
        temperature: '34.2 °C',
        humidity: '45 %',
        weight: '24.5 kg',
        acoustics: 'Normal (Buzz)',
        battery: '82%',
        recordedAt: new Date(Date.now() - 864000000).toISOString()
      },
      aiAnalysis: {
        healthStatus: 'Excellent',
        riskLevel: 'Low',
        anomalyScore: 0.02,
        temperatureStatus: 'Optimal',
        humidityStatus: 'Optimal',
        weightStatus: 'Increasing',
        acousticStatus: 'Normal',
        analyzedAt: new Date(Date.now() - 864000000).toISOString()
      },
      collection: {
        center: 'Nilgiris Collection Hub',
        collector: 'Ramesh Kumar',
        receivedDate: new Date(Date.now() - 777600000).toISOString(),
        quantityKg: 100,
        status: 'Quality Assured'
      },
      processing: {
        processor: 'HoneyChain Central Processing',
        processingDate: new Date(Date.now() - 604800000).toISOString(),
        method: 'Cold Filtration',
        inputQuantityKg: 100,
        outputQuantityKg: 96,
        status: 'Processed'
      },
      collectionProcessing: {
        processor: 'HoneyChain Central Processing',
        processingDate: new Date(Date.now() - 604800000).toISOString(),
        method: 'Cold Filtration',
        inputQuantityKg: 100,
        outputQuantityKg: 96,
        status: 'Processed'
      },
      labVerification: {
        labName: 'National Honey Testing Laboratory',
        reportId: 'REP-5555-89',
        qualityScore: 98,
        status: 'PASSED',
        parameters: [
          { name: 'Moisture', value: '17.5%', standard: '< 20%', status: 'Pass' },
          { name: 'HMF', value: '12 mg/kg', standard: '< 40 mg/kg', status: 'Pass' },
          { name: 'Acidity', value: '22 meq/kg', standard: '< 50 meq/kg', status: 'Pass' },
          { name: 'Sugar Profile (F/G ratio)', value: '1.2', standard: '> 1.0', status: 'Pass' },
          { name: 'Adulteration (C4 Sugars)', value: 'Not Detected', standard: 'Negative', status: 'Pass' },
          { name: 'Microbiology', value: 'Absent', standard: 'Absent', status: 'Pass' }
        ]
      },
      packaging: {
        facility: 'HoneyChain Packagers Ltd',
        packagingDate: new Date(Date.now() - 86400000).toISOString(),
        sealStatus: 'Sealed',
        numberOfPackages: 200,
        packageSize: '500g'
      },
      blockchainVerification: {
        network: 'Polygon',
        contractAddress: '0x000000000000000000000000000000000000A1B2',
        onChainConfigured: true,
        onChainReadSuccess: true,
        onChainEventCount: 6,
        ledgerStatus: 'VERIFIED',
        totalConfirmedEvents: 6,
        latestTxHash: '0xabc1237f89d38c11',
        events: []
      },
      provenanceEvents: [],
      events: []
    };
  }

  const url = `${API_BASE}/api/public/verify/${encodeURIComponent(batchId)}`;
  const res = await fetch(url, {
    headers: {
      'Accept': 'application/json',
    },
  });

  if (res.status === 404) {
    return {
      success: false,
      found: false,
      batchId,
      traceabilityId: batchId,
      status: 'UNVERIFIED BATCH',
      currentStage: 'NOT FOUND',
      isFullyVerified: false,
      verificationTimestamp: new Date().toISOString(),
      product: {} as any,
      harvester: {} as any,
      iotTelemetry: null,
      aiAnalysis: null,
      collection: null,
      processing: null,
      collectionProcessing: null,
      labVerification: null,
      packaging: null,
      blockchainVerification: {
        network: 'Not configured',
        contractAddress: null,
        onChainConfigured: false,
        onChainReadSuccess: false,
        onChainEventCount: 0,
        ledgerStatus: 'NO_RECORDS',
        totalConfirmedEvents: 0,
        latestTxHash: null,
        events: [],
      },
      provenanceEvents: [],
      events: [],
    };
  }

  if (!res.ok) {
    throw new Error(`HoneyChain verification service returned status ${res.status}`);
  }

  const data = await res.json();
  return data;
}
