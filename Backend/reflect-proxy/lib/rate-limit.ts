import { Redis } from "@upstash/redis";

import { getConfig } from "./config.js";

const ATOMIC_FIXED_WINDOW_SCRIPT = `
for index, key in ipairs(KEYS) do
  local limit = tonumber(ARGV[(index - 1) * 2 + 1])
  local current = tonumber(redis.call("GET", key) or "0")
  if current >= limit then
    return 0
  end
end

for index, key in ipairs(KEYS) do
  local windowSeconds = tonumber(ARGV[(index - 1) * 2 + 2])
  local count = redis.call("INCR", key)
  if count == 1 then
    redis.call("EXPIRE", key, windowSeconds)
  end
end

return 1
`.trim();

const REFLECTION_LIMITS: RateLimitRule[] = [
  { key: "device-hour", limit: 10, windowSeconds: 60 * 60 },
  { key: "device-day", limit: 30, windowSeconds: 24 * 60 * 60 },
  { key: "ip-hour", limit: 30, windowSeconds: 60 * 60 }
];

const DEVICE_TOKEN_LIMITS: RateLimitRule[] = [
  { key: "token-issuance-ip-hour", limit: 10, windowSeconds: 60 * 60 },
  { key: "token-issuance-ip-day", limit: 30, windowSeconds: 24 * 60 * 60 }
];

export class RateLimitExceededError extends Error {
  constructor(public readonly code = "rate_limited") {
    super(code);
    this.name = "RateLimitExceededError";
  }
}

export class RateLimitUnavailableError extends Error {
  constructor(public readonly code = "rate_limit_unavailable") {
    super(code);
    this.name = "RateLimitUnavailableError";
  }
}

type RateLimitInput = {
  tokenHash: string;
  ip: string;
  now: Date;
};

type DeviceTokenRateLimitInput = {
  ip: string;
  now: Date;
};

type RateLimitRule = {
  key: string;
  limit: number;
  windowSeconds: number;
};

type ResolvedRateLimit = RateLimitRule & {
  storageKey: string;
};

interface AtomicRateLimitStore {
  consume(limits: ResolvedRateLimit[]): Promise<boolean>;
  reset?(): void;
}

class MemoryRateLimitStore implements AtomicRateLimitStore {
  private readonly counters = new Map<string, number>();

  async consume(limits: ResolvedRateLimit[]): Promise<boolean> {
    if (limits.some((limit) => (this.counters.get(limit.storageKey) ?? 0) >= limit.limit)) {
      return false;
    }

    for (const limit of limits) {
      this.counters.set(limit.storageKey, (this.counters.get(limit.storageKey) ?? 0) + 1);
    }
    return true;
  }

  reset(): void {
    this.counters.clear();
  }
}

type EvaluateScript = (script: string, keys: string[], args: number[]) => Promise<number>;

export class UpstashRateLimitStore implements AtomicRateLimitStore {
  constructor(private readonly evaluate: EvaluateScript) {}

  async consume(limits: ResolvedRateLimit[]): Promise<boolean> {
    try {
      const result = await this.evaluate(
        ATOMIC_FIXED_WINDOW_SCRIPT,
        limits.map((limit) => limit.storageKey),
        limits.flatMap((limit) => [limit.limit, limit.windowSeconds])
      );
      return result === 1;
    } catch {
      throw new RateLimitUnavailableError();
    }
  }
}

let cachedStore: AtomicRateLimitStore | undefined;

export async function enforceRateLimit(input: RateLimitInput): Promise<void> {
  await consumeOrThrow(
    REFLECTION_LIMITS.map((rule) => ({
      ...rule,
      storageKey: bucketKey(rule.key.startsWith("device") ? input.tokenHash : input.ip, rule, input.now)
    }))
  );
}

export async function enforceDeviceTokenIssuanceRateLimit(
  input: DeviceTokenRateLimitInput
): Promise<void> {
  await consumeOrThrow(
    DEVICE_TOKEN_LIMITS.map((rule) => ({
      ...rule,
      storageKey: bucketKey(input.ip, rule, input.now)
    }))
  );
}

async function consumeOrThrow(limits: ResolvedRateLimit[]): Promise<void> {
  const allowed = await rateLimitStore().consume(limits);
  if (!allowed) {
    throw new RateLimitExceededError();
  }
}

function rateLimitStore(): AtomicRateLimitStore {
  if (cachedStore) {
    return cachedStore;
  }

  const config = getConfig();
  const hasUrl = Boolean(config.UPSTASH_REDIS_REST_URL);
  const hasToken = Boolean(config.UPSTASH_REDIS_REST_TOKEN);

  if (hasUrl && hasToken) {
    const redis = new Redis({
      url: config.UPSTASH_REDIS_REST_URL!,
      token: config.UPSTASH_REDIS_REST_TOKEN!,
      retry: false
    });
    cachedStore = new UpstashRateLimitStore((script, keys, args) =>
      redis.eval<number[], number>(script, keys, args)
    );
    return cachedStore;
  }

  if (config.VERCEL_ENV === "production" || config.VERCEL_ENV === "preview") {
    throw new RateLimitUnavailableError();
  }

  cachedStore = new MemoryRateLimitStore();
  return cachedStore;
}

function bucketKey(identifier: string, rule: RateLimitRule, now: Date): string {
  const windowStart = Math.floor(now.getTime() / (rule.windowSeconds * 1000));
  return `daily-better:rate-limit:${rule.key}:${identifier}:${windowStart}`;
}

export function resetRateLimitsForTests(): void {
  cachedStore?.reset?.();
  cachedStore = undefined;
}
