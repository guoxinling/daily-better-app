import { afterEach, beforeEach, expect, test } from "vitest";

import { buildReflectHandler } from "../api/reflect.js";
import { resetConfigForTests } from "../lib/config.js";
import { listMetricsForTests, resetMetricsForTests } from "../lib/metrics.js";
import { resetRateLimitsForTests } from "../lib/rate-limit.js";
import { reflectRequestSchema } from "../lib/schema.js";
import { issueDeviceToken } from "../lib/tokens.js";

const TEST_SECRET = "test-device-token-secret-value-2026";

type ResponseState = {
  statusCode?: number;
  body?: unknown;
};

function makeResponseRecorder() {
  const state: ResponseState = {};

  return {
    state,
    response: {
      status(code: number) {
        state.statusCode = code;
        return this;
      },
      json(body: unknown) {
        state.body = body;
      }
    }
  };
}

beforeEach(() => {
  process.env.DEVICE_TOKEN_SECRET = TEST_SECRET;
  process.env.DEEPSEEK_API_KEY = "test-deepseek-api-key";
  delete process.env.DEEPSEEK_MODEL;
  resetConfigForTests();
  resetMetricsForTests();
  resetRateLimitsForTests();
});

afterEach(() => {
  delete process.env.DEVICE_TOKEN_SECRET;
  delete process.env.DEEPSEEK_API_KEY;
  delete process.env.DEEPSEEK_MODEL;
  resetConfigForTests();
  resetMetricsForTests();
  resetRateLimitsForTests();
});

test("reflect request schema accepts all current mood keys", () => {
  const currentMoods = ["bright", "calm", "okay", "low", "anxious", "overwhelmed"];

  for (const mood of currentMoods) {
    const result = reflectRequestSchema.safeParse({
      deviceToken: "device-token",
      requestId: "11111111-1111-4111-8111-111111111111",
      mood,
      noteText: "A note.",
      locale: "en_US",
      appVersion: "1.2.0"
    });

    expect(result.success, `expected current mood ${mood} to be accepted`).toBe(true);
  }
});

test("reflect request schema rejects retired mood keys", () => {
  const retiredMoods = ["good", "frustrated", "drained"];

  for (const mood of retiredMoods) {
    const result = reflectRequestSchema.safeParse({
      deviceToken: "device-token",
      requestId: "11111111-1111-4111-8111-111111111111",
      mood,
      noteText: "A note.",
      locale: "en_US",
      appVersion: "1.2.0"
    });

    expect(result.success, `expected retired mood ${mood} to be rejected`).toBe(false);
  }
});

test("reflect request schema rejects non-UUID request IDs", () => {
  const result = reflectRequestSchema.safeParse({
    deviceToken: "device-token",
    requestId: "request-id",
    mood: "calm",
    noteText: "A note.",
    locale: "en_US",
    appVersion: "1.2.0"
  });

  expect(result.success).toBe(false);
});

test.each([
  ["deviceToken", "x".repeat(2049)],
  ["locale", "x".repeat(33)],
  ["appVersion", "x".repeat(33)]
])("reflect request schema bounds %s", (field, value) => {
  const result = reflectRequestSchema.safeParse({
    deviceToken: "device-token",
    requestId: "11111111-1111-4111-8111-111111111111",
    mood: "calm",
    noteText: "A note.",
    locale: "en_US",
    appVersion: "1.2.0",
    [field]: value
  });

  expect(result.success).toBe(false);
});

test("reflect returns structured ai payload", async () => {
  const validToken = (await issueDeviceToken(new Date("2026-07-06T00:00:00Z"))).deviceToken;
  const { response, state } = makeResponseRecorder();
  const handler = buildReflectHandler({
    now: () => new Date("2026-07-06T00:00:00Z"),
    requestReflection: async () => ({
      reflectionText: "Your mind is still active, but this moment can be smaller than the whole night.",
      suggestedActionText: "Loosen your shoulders and name one thing that is already done today.",
      providerModel: "deepseek-v4-flash",
      promptTokens: 42,
      completionTokens: 28
    })
  });

  await handler(
    {
      method: "POST",
      headers: { "x-forwarded-for": "203.0.113.10" },
      body: {
        deviceToken: validToken,
        requestId: "11111111-1111-4111-8111-111111111101",
        mood: "anxious",
        noteText: "I can't slow down tonight.",
        locale: "en_US",
        appVersion: "1.2.0"
      }
    },
    response
  );

  expect(state.statusCode).toBe(200);
  expect(state.body).toEqual({
    reflectionText: "Your mind is still active, but this moment can be smaller than the whole night.",
    suggestedActionText: "Loosen your shoulders and name one thing that is already done today.",
    source: "ai"
  });

  expect(listMetricsForTests()).toHaveLength(1);
  expect(listMetricsForTests()[0]?.success).toBe(true);
  expect("noteText" in (listMetricsForTests()[0] as object)).toBe(false);
});

test("reflect rejects invalid token with 401", async () => {
  const { response, state } = makeResponseRecorder();
  const handler = buildReflectHandler();

  await handler(
    {
      method: "POST",
      body: {
        deviceToken: "invalid-token",
        requestId: "11111111-1111-4111-8111-111111111102",
        mood: "bright",
        noteText: "A small good thing happened.",
        locale: "en_US",
        appVersion: "1.2.0"
      }
    },
    response
  );

  expect(state.statusCode).toBe(401);
  expect(state.body).toEqual({ error: "invalid_device_token" });
  expect(listMetricsForTests()).toHaveLength(0);
});

test("reflect returns safe field details for invalid request payloads", async () => {
  const { response, state } = makeResponseRecorder();
  const handler = buildReflectHandler();

  await handler(
    {
      method: "POST",
      body: {
        deviceToken: "device-token",
        requestId: "11111111-1111-4111-8111-111111111106",
        mood: "low",
        noteText: "I feel tired today.",
        locale: "en_US",
        appVersion: "x".repeat(33)
      }
    },
    response
  );

  expect(state.statusCode).toBe(400);
  expect(state.body).toEqual({
    error: "invalid_request",
    fieldErrors: [{ field: "appVersion", reason: "too_big" }]
  });
});

test("reflect rejects over-limit request with 429", async () => {
  const validToken = (await issueDeviceToken(new Date("2026-07-06T00:00:00Z"))).deviceToken;
  const handler = buildReflectHandler({
    now: () => new Date("2026-07-06T00:00:00Z"),
    requestReflection: async () => ({
      reflectionText: "You only need one next step.",
      suggestedActionText: "Write the first step, not the full plan.",
      providerModel: "deepseek-v4-flash"
    })
  });

  for (let index = 0; index < 10; index += 1) {
    const { response } = makeResponseRecorder();
    await handler(
      {
        method: "POST",
        headers: { "x-forwarded-for": "203.0.113.20" },
        body: {
          deviceToken: validToken,
          requestId: `11111111-1111-4111-8111-${String(index).padStart(12, "0")}`,
          mood: "overwhelmed",
          noteText: "Everything is competing for attention.",
          locale: "en_US",
          appVersion: "1.2.0"
        }
      },
      response
    );
  }

  const { response, state } = makeResponseRecorder();
  await handler(
    {
      method: "POST",
      headers: { "x-forwarded-for": "203.0.113.20" },
      body: {
        deviceToken: validToken,
        requestId: "11111111-1111-4111-8111-111111111103",
        mood: "overwhelmed",
        noteText: "Everything is competing for attention.",
        locale: "en_US",
        appVersion: "1.2.0"
      }
    },
    response
  );

  expect(state.statusCode).toBe(429);
  expect(state.body).toEqual({ error: "rate_limited" });
});

test("reflect rejects malformed model payload with 502", async () => {
  const validToken = (await issueDeviceToken(new Date("2026-07-06T00:00:00Z"))).deviceToken;
  const { response, state } = makeResponseRecorder();
  const handler = buildReflectHandler({
    now: () => new Date("2026-07-06T00:00:00Z"),
    requestReflection: async () => {
      throw new Error("invalid_model_payload");
    }
  });

  await handler(
    {
      method: "POST",
      headers: { "x-forwarded-for": "203.0.113.30" },
      body: {
        deviceToken: validToken,
        requestId: "11111111-1111-4111-8111-111111111104",
        mood: "anxious",
        noteText: "I keep replaying the same sharp conversation.",
        locale: "en_US",
        appVersion: "1.2.0"
      }
    },
    response
  );

  expect(state.statusCode).toBe(502);
  expect(state.body).toEqual({ error: "provider_unavailable" });
  expect(listMetricsForTests()).toHaveLength(1);
  expect(listMetricsForTests()[0]?.success).toBe(false);
});

test("reflect failure metric uses the configured DeepSeek model", async () => {
  process.env.DEEPSEEK_MODEL = "deepseek-custom-model";
  resetConfigForTests();
  const validToken = (await issueDeviceToken(new Date("2026-07-06T00:00:00Z"))).deviceToken;
  const { response } = makeResponseRecorder();
  const handler = buildReflectHandler({
    now: () => new Date("2026-07-06T00:00:00Z"),
    requestReflection: async () => {
      throw new Error("provider failed");
    }
  });

  await handler(
    {
      method: "POST",
      headers: { "x-forwarded-for": "203.0.113.31" },
      body: {
        deviceToken: validToken,
        requestId: "11111111-1111-4111-8111-111111111105",
        mood: "low",
        noteText: "Today has felt heavy.",
        locale: "en_US",
        appVersion: "1.2.0"
      }
    },
    response
  );

  expect(listMetricsForTests()[0]?.providerModel).toBe("deepseek-custom-model");
});
