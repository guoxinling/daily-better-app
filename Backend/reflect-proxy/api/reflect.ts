import { createHash } from "node:crypto";

import {
  InvalidModelPayloadError,
  ProviderUnavailableError,
  requestReflectionFromDeepSeek
} from "../lib/deepseek.js";
import { recordMetric } from "../lib/metrics.js";
import {
  enforceRateLimit,
  RateLimitExceededError,
  RateLimitUnavailableError
} from "../lib/rate-limit.js";
import { reflectRequestSchema, type ReflectRequest } from "../lib/schema.js";
import { verifyDeviceToken } from "../lib/tokens.js";

type JsonValue =
  | boolean
  | number
  | string
  | null
  | JsonValue[]
  | { [key: string]: JsonValue };

export type VercelRequestLike = {
  method?: string;
  body?: unknown;
  headers?: Record<string, string | string[] | undefined>;
  socket?: {
    remoteAddress?: string;
  };
};

export type VercelResponseLike = {
  status(code: number): VercelResponseLike;
  json(body: JsonValue): void;
};

type DeepSeekReflectionResult = Awaited<ReturnType<typeof requestReflectionFromDeepSeek>>;

type ReflectDependencies = {
  now?: () => Date;
  verifyToken?: typeof verifyDeviceToken;
  enforceRateLimit?: typeof enforceRateLimit;
  requestReflection?: (input: ReflectRequest) => Promise<DeepSeekReflectionResult>;
  recordMetric?: typeof recordMetric;
  hashToken?: (token: string) => string;
};

export function buildReflectHandler(dependencies: ReflectDependencies = {}) {
  const now = dependencies.now ?? (() => new Date());
  const verifyToken = dependencies.verifyToken ?? verifyDeviceToken;
  const limit = dependencies.enforceRateLimit ?? enforceRateLimit;
  const requestReflection = dependencies.requestReflection ?? requestReflectionFromDeepSeek;
  const record = dependencies.recordMetric ?? recordMetric;
  const hashToken = dependencies.hashToken ?? sha256;

  return async function handler(req: VercelRequestLike, res: VercelResponseLike) {
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }

    const parsed = reflectRequestSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "invalid_request" });
      return;
    }

    const requestBody = parsed.data;
    const requestTime = now();
    const tokenHash = hashToken(requestBody.deviceToken);
    const ip = requestIp(req);

    try {
      await verifyToken(requestBody.deviceToken);
    } catch {
      res.status(401).json({ error: "invalid_device_token" });
      return;
    }

    try {
      await limit({
        tokenHash,
        ip,
        now: requestTime
      });

      const ai = await requestReflection(requestBody);
      await record({
        requestId: requestBody.requestId,
        deviceTokenHash: tokenHash,
        appVersion: requestBody.appVersion,
        latencyMs: Math.max(0, now().getTime() - requestTime.getTime()),
        providerModel: ai.providerModel,
        promptTokens: ai.promptTokens,
        completionTokens: ai.completionTokens,
        success: true
      });

      res.status(200).json({
        reflectionText: ai.reflectionText,
        suggestedActionText: ai.suggestedActionText,
        source: "ai"
      });
    } catch (error) {
      const errorCode = classifyError(error);
      await record({
        requestId: requestBody.requestId,
        deviceTokenHash: tokenHash,
        appVersion: requestBody.appVersion,
        latencyMs: Math.max(0, now().getTime() - requestTime.getTime()),
        providerModel: "deepseek-v4-flash",
        success: false,
        errorCode
      });

      res.status(statusForError(error)).json({ error: errorCode });
    }
  };
}

export default buildReflectHandler();

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

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function statusForError(error: unknown): number {
  if (error instanceof RateLimitExceededError) {
    return 429;
  }

  if (error instanceof RateLimitUnavailableError) {
    return 503;
  }

  if (error instanceof ProviderUnavailableError || error instanceof InvalidModelPayloadError) {
    return 502;
  }

  return 502;
}

function classifyError(error: unknown): string {
  if (error instanceof RateLimitExceededError) {
    return error.code;
  }

  if (error instanceof RateLimitUnavailableError) {
    return error.code;
  }

  if (error instanceof InvalidModelPayloadError) {
    return error.code;
  }

  if (error instanceof ProviderUnavailableError) {
    return error.code;
  }

  return "provider_unavailable";
}
