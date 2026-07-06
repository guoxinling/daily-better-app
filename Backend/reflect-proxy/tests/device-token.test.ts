import { expect, test } from "vitest";

import { issueDeviceToken } from "../lib/tokens.js";

test("issueDeviceToken returns opaque token with expiry", async () => {
  const token = await issueDeviceToken(new Date("2026-07-06T00:00:00Z"));

  expect(token.deviceToken).toBeTruthy();
  expect(token.expiresAt).toBe("2026-08-05T00:00:00.000Z");
});
