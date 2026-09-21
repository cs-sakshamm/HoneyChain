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

export interface ProcessingInfo {
  processor: string;
  method: string;
  quantityReceivedKg: number | string;
  moistureAtReceipt: string;
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
  collectionProcessing: ProcessingInfo | null;
  labVerification: LabVerificationInfo | null;
  packaging: PackagingInfoData | null;
  blockchainVerification: BlockchainVerificationInfo;
  provenanceEvents: BlockchainEvent[];
  events: BlockchainEvent[];
}

const API_BASE = (import.meta.env.VITE_API_URL || import.meta.env.VITE_API_BASE_URL || '').replace(/\/$/, '');

export async function fetchVerificationData(batchId: string): Promise<VerificationResponse> {
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
