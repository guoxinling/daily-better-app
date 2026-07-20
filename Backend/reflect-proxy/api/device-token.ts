import { issueDeviceToken } from "../lib/tokens.js";
import {
  enforceDeviceTokenIssuanceRateLimit,
  RateLimitExceededError,
  RateLimitUnavailableError
} from "../lib/rate-limit.js";

type JsonValue = boolean | number | string | null | JsonValue[] | { [key: string]: JsonValue };

type VercelRequestLike = {
  method?: string;
  headers?: Record<string, string | string[] | undefined>;
  socket?: {
    remoteAddress?: string;
  };
};

type VercelResponseLike = {
  status(code: number): VercelResponseLike;
  json(body: JsonValue): void;
};

export default async function handler(req: VercelRequestLike, res: VercelResponseLike) {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }

  try {
    await enforceDeviceTokenIssuanceRateLimit({
      ip: requestIp(req),
      now: new Date()
    });
    const token = await issueDeviceToken();
    res.status(200).json(token);
  } catch (error) {
    if (error instanceof RateLimitExceededError) {
      res.status(429).json({ error: error.code });
      return;
    }

    if (error instanceof RateLimitUnavailableError) {
      res.status(503).json({ error: error.code });
      return;
    }

    throw error;
  }
}

function requestIp(req: VercelRequestLike): string {
  const forwarded = req.headers?.["x-forwarded-for"];
  if (typeof forwarded === "string") {
    return forwarded.split(",")[0]?.trim() || "unknown";
  }

  if (Array.isArray(forwarded)) {
    return forwarded[0]?.split(",")[0]?.trim() || "unknown";
  }

  return req.socket?.remoteAddress ?? "unknown";
}
