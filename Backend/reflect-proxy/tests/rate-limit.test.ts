import { afterEach, beforeEach, expect, test, vi } from "vitest";

import { resetConfigForTests } from "../lib/config.js";
import {
  enforceRateLimit,
  resetRateLimitsForTests,
  UpstashRateLimitStore
} from "../lib/rate-limit.js";

beforeEach(() => {
  process.env.DEVICE_TOKEN_SECRET = "test-device-token-secret-value-2026";
  process.env.VERCEL_ENV = "production";
  delete process.env.UPSTASH_REDIS_REST_URL;
  delete process.env.UPSTASH_REDIS_REST_TOKEN;
  resetRateLimitsForTests();
  resetConfigForTests();
});

afterEach(() => {
  delete process.env.VERCEL_ENV;
  delete process.env.DEVICE_TOKEN_SECRET;
  delete process.env.UPSTASH_REDIS_REST_URL;
  delete process.env.UPSTASH_REDIS_REST_TOKEN;
  resetRateLimitsForTests();
  resetConfigForTests();
});

test("production rate limiting fails closed when shared Redis is not configured", async () => {
  await expect(
    enforceRateLimit({
      tokenHash: "token-hash",
      ip: "203.0.113.8",
      now: new Date("2026-07-21T00:00:00Z")
    })
  ).rejects.toMatchObject({ code: "rate_limit_unavailable" });
});

test("production rate limiting consumes all limits with one atomic Redis script", async () => {
  const evaluate = vi.fn(async (_script: string, _keys: string[], _args: number[]) => 1);
  const store = new UpstashRateLimitStore(evaluate);

  await store.consume([
    {
      key: "device-hour",
      storageKey: "daily-better:rate-limit:device-hour:token-hash:1",
      limit: 10,
      windowSeconds: 3600
    },
    {
      key: "device-day",
      storageKey: "daily-better:rate-limit:device-day:token-hash:1",
      limit: 30,
      windowSeconds: 86400
    }
  ]);

  expect(evaluate).toHaveBeenCalledOnce();
  const [script, keys, args] = evaluate.mock.calls[0]!;
  expect(script).toContain("for index, key in ipairs(KEYS)");
  expect(keys).toEqual([
    "daily-better:rate-limit:device-hour:token-hash:1",
    "daily-better:rate-limit:device-day:token-hash:1"
  ]);
  expect(args).toEqual([10, 3600, 30, 86400]);
});
