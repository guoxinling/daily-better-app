import { afterEach, expect, test, vi } from "vitest";

import { listMetricsForTests, recordMetric, resetMetricsForTests } from "../lib/metrics.js";

afterEach(() => {
  delete process.env.VERCEL_ENV;
  resetMetricsForTests();
  vi.restoreAllMocks();
});

test("local metrics retain only the latest 100 sanitized records", async () => {
  for (let index = 0; index < 101; index += 1) {
    await recordMetric({
      requestId: `request-${index}`,
      deviceTokenHash: `device-${index}`,
      appVersion: "1.2.0",
      latencyMs: index,
      providerModel: "deepseek-v4-flash",
      success: true
    });
  }

  const metrics = listMetricsForTests();
  expect(metrics).toHaveLength(100);
  expect(metrics[0]?.latencyMs).toBe(1);
  expect(metrics[99]?.latencyMs).toBe(100);
  expect(metrics[0]).toHaveProperty("requestIdHash");
  expect(metrics[0]).not.toHaveProperty("requestId");
  expect(metrics[0]).not.toHaveProperty("deviceTokenHash");
});

test("production metrics emit sanitized structured logs without retaining records", async () => {
  process.env.VERCEL_ENV = "production";
  const info = vi.spyOn(console, "info").mockImplementation(() => undefined);

  await recordMetric({
    requestId: "11111111-1111-4111-8111-111111111111",
    deviceTokenHash: "sensitive-stable-device-hash",
    appVersion: "1.2.0",
    latencyMs: 120,
    providerModel: "deepseek-v4-flash",
    success: false,
    errorCode: "provider_unavailable"
  });

  expect(listMetricsForTests()).toEqual([]);
  expect(info).toHaveBeenCalledOnce();
  const serialized = String(info.mock.calls[0]?.[1]);
  expect(serialized).toContain("requestIdHash");
  expect(serialized).not.toContain("11111111-1111-4111-8111-111111111111");
  expect(serialized).not.toContain("sensitive-stable-device-hash");
});
