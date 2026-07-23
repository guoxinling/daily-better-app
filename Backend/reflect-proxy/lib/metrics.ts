import { createHash } from "node:crypto";

const LOCAL_METRIC_LIMIT = 100;

export type MetricRecord = {
  requestIdHash: string;
  timestamp: string;
  appVersion: string;
  latencyMs: number;
  providerModel: string;
  promptTokens?: number;
  completionTokens?: number;
  success: boolean;
  errorCode?: string;
};

type RecordMetricInput = Omit<MetricRecord, "requestIdHash" | "timestamp"> & {
  requestId: string;
  deviceTokenHash: string;
  timestamp?: Date;
};

const metricsStore: MetricRecord[] = [];

export async function recordMetric(input: RecordMetricInput): Promise<void> {
  const { requestId, deviceTokenHash: _discardedDeviceTokenHash, timestamp, ...values } = input;
  const record: MetricRecord = {
    ...values,
    requestIdHash: shortHash(requestId),
    timestamp: (timestamp ?? new Date()).toISOString()
  };

  if (process.env.VERCEL_ENV === "production" || process.env.VERCEL_ENV === "preview") {
    console.info("daily_better_reflect_metric", JSON.stringify(record));
    return;
  }

  metricsStore.push(record);
  if (metricsStore.length > LOCAL_METRIC_LIMIT) {
    metricsStore.splice(0, metricsStore.length - LOCAL_METRIC_LIMIT);
  }
}

export function listMetricsForTests(): MetricRecord[] {
  return [...metricsStore];
}

export function resetMetricsForTests(): void {
  metricsStore.length = 0;
}

function shortHash(value: string): string {
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}
