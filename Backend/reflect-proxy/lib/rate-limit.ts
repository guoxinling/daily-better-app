const bucketEvents = new Map<string, number[]>();

export class RateLimitExceededError extends Error {
  constructor(public readonly code = "rate_limited") {
    super(code);
    this.name = "RateLimitExceededError";
  }
}

type RateLimitInput = {
  tokenHash: string;
  ip: string;
  now: Date;
};

export async function enforceRateLimit(input: RateLimitInput): Promise<void> {
  const nowMs = input.now.getTime();
  assertBucket(`device:${input.tokenHash}:hour`, 10, 60 * 60, nowMs);
  assertBucket(`device:${input.tokenHash}:day`, 30, 24 * 60 * 60, nowMs);
  assertBucket(`ip:${input.ip}:hour`, 30, 60 * 60, nowMs);
}

function assertBucket(key: string, limit: number, windowSeconds: number, nowMs: number): void {
  const threshold = nowMs - windowSeconds * 1000;
  const recentEvents = (bucketEvents.get(key) ?? []).filter((timestamp) => timestamp > threshold);
  if (recentEvents.length >= limit) {
    bucketEvents.set(key, recentEvents);
    throw new RateLimitExceededError();
  }

  recentEvents.push(nowMs);
  bucketEvents.set(key, recentEvents);
}

export function resetRateLimitsForTests(): void {
  bucketEvents.clear();
}
