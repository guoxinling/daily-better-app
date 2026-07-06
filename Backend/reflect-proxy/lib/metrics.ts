export type MetricRecord = {
  requestId: string;
  deviceTokenHash: string;
  timestamp: string;
  appVersion: string;
  latencyMs: number;
  providerModel: string;
  promptTokens?: number;
  completionTokens?: number;
  success: boolean;
  errorCode?: string;
};

type RecordMetricInput = Omit<MetricRecord, "timestamp"> & {
  timestamp?: Date;
};

const metricsStore: MetricRecord[] = [];

export async function recordMetric(input: RecordMetricInput): Promise<void> {
  metricsStore.push({
    ...input,
    timestamp: (input.timestamp ?? new Date()).toISOString()
  });
}

export function listMetricsForTests(): MetricRecord[] {
  return [...metricsStore];
}

export function resetMetricsForTests(): void {
  metricsStore.length = 0;
}
