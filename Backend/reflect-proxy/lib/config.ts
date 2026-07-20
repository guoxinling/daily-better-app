import { z } from "zod";

const envSchema = z.object({
  DEVICE_TOKEN_SECRET: z.string().min(32),
  DEVICE_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),
  DEEPSEEK_API_KEY: z.string().min(1).optional(),
  DEEPSEEK_MODEL: z.string().min(1).default("deepseek-v4-flash"),
  UPSTASH_REDIS_REST_URL: z.string().url().optional(),
  UPSTASH_REDIS_REST_TOKEN: z.string().min(1).optional(),
  VERCEL_ENV: z.enum(["production", "preview", "development"]).optional()
});

export type BackendConfig = z.infer<typeof envSchema>;

let cachedConfig: BackendConfig | undefined;

export function getConfig(): BackendConfig {
  cachedConfig ??= envSchema.parse(process.env);
  return cachedConfig;
}

export function resetConfigForTests(): void {
  cachedConfig = undefined;
}
