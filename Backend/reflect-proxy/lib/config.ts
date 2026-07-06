import { z } from "zod";

const envSchema = z.object({
  DEVICE_TOKEN_SECRET: z.string().min(32),
  DEVICE_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30)
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
