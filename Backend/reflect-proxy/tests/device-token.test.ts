import { afterEach, beforeEach, expect, test } from "vitest";

import handler from "../api/device-token.js";
import { resetConfigForTests } from "../lib/config.js";
import { resetRateLimitsForTests } from "../lib/rate-limit.js";
import { issueDeviceToken } from "../lib/tokens.js";
import { verifyDeviceToken } from "../lib/tokens.js";

const TEST_SECRET = "test-device-token-secret-value-2026";

function makeResponseRecorder() {
  const state: {
    statusCode?: number;
    body?: unknown;
  } = {};

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
  delete process.env.DEVICE_TOKEN_TTL_DAYS;
  resetConfigForTests();
  resetRateLimitsForTests();
});

afterEach(() => {
  delete process.env.DEVICE_TOKEN_SECRET;
  delete process.env.DEVICE_TOKEN_TTL_DAYS;
  resetConfigForTests();
  resetRateLimitsForTests();
});

test("issueDeviceToken returns opaque token with expiry", async () => {
  const token = await issueDeviceToken(new Date("2026-07-06T00:00:00Z"));

  expect(token.deviceToken).toBeTruthy();
  expect(token.expiresAt).toBe("2026-08-05T00:00:00.000Z");
});

test("issueDeviceToken fails fast when DEVICE_TOKEN_SECRET is missing", async () => {
  delete process.env.DEVICE_TOKEN_SECRET;
  resetConfigForTests();

  await expect(issueDeviceToken(new Date("2026-07-06T00:00:00Z"))).rejects.toThrow();
});

test("verifyDeviceToken returns payload for a valid token", async () => {
  const issued = await issueDeviceToken(new Date("2026-07-06T00:00:00Z"));

  const payload = await verifyDeviceToken(issued.deviceToken);

  expect(payload.scope).toBe("reflect-device");
  expect(payload.iat).toBeDefined();
  expect(payload.exp).toBeDefined();
});

test("verifyDeviceToken rejects an invalid token", async () => {
  await expect(verifyDeviceToken("not-a-valid-token")).rejects.toThrow();
});

test("device-token handler returns 405 for non-POST requests", async () => {
  const { response, state } = makeResponseRecorder();

  await handler({ method: "GET" }, response);

  expect(state.statusCode).toBe(405);
  expect(state.body).toEqual({ error: "method_not_allowed" });
});

test("device-token handler rate limits issuance by source IP", async () => {
  for (let index = 0; index < 10; index += 1) {
    const { response, state } = makeResponseRecorder();

    await handler(
      {
        method: "POST",
        headers: { "x-forwarded-for": "203.0.113.42" }
      },
      response
    );

    expect(state.statusCode).toBe(200);
  }

  const { response, state } = makeResponseRecorder();
  await handler(
    {
      method: "POST",
      headers: { "x-forwarded-for": "203.0.113.42" }
    },
    response
  );

  expect(state.statusCode).toBe(429);
  expect(state.body).toEqual({ error: "rate_limited" });
});
