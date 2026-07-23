import { createSecretKey, randomUUID } from "node:crypto";

import { jwtVerify, SignJWT } from "jose";

import { getConfig } from "./config.js";

const DEVICE_TOKEN_SCOPE = "reflect-device";
const MILLISECONDS_PER_DAY = 24 * 60 * 60 * 1000;

export type IssuedDeviceToken = {
  deviceToken: string;
  issuedAt: string;
  expiresAt: string;
};

type DeviceTokenPayload = {
  scope: typeof DEVICE_TOKEN_SCOPE;
};

function secretKey() {
  return createSecretKey(Buffer.from(getConfig().DEVICE_TOKEN_SECRET, "utf8"));
}

export async function issueDeviceToken(now = new Date()): Promise<IssuedDeviceToken> {
  const issuedAt = now.toISOString();
  const expiresAtDate = new Date(
    now.getTime() + getConfig().DEVICE_TOKEN_TTL_DAYS * MILLISECONDS_PER_DAY
  );
  const expiresAt = expiresAtDate.toISOString();

  const deviceToken = await new SignJWT({ scope: DEVICE_TOKEN_SCOPE satisfies DeviceTokenPayload["scope"] })
    .setProtectedHeader({ alg: "HS256" })
    .setJti(randomUUID())
    .setIssuedAt(now)
    .setExpirationTime(expiresAtDate)
    .sign(secretKey());

  return {
    deviceToken,
    issuedAt,
    expiresAt
  };
}

export async function verifyDeviceToken(token: string) {
  const verified = await jwtVerify(token, secretKey());

  if (verified.payload.scope !== DEVICE_TOKEN_SCOPE) {
    throw new Error("invalid_device_token_scope");
  }

  return verified.payload;
}
