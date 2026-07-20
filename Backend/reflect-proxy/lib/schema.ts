import { z } from "zod";

export const reflectRequestSchema = z.object({
  deviceToken: z.string().trim().min(1),
  requestId: z.string().trim().min(1),
  mood: z.enum(["bright", "calm", "okay", "low", "anxious", "overwhelmed"]),
  noteText: z.string().trim().min(1).max(4000),
  locale: z.string().trim().min(2),
  appVersion: z.string().trim().min(1)
});

export const deepseekResponseSchema = z.object({
  reflectionText: z.string().trim().min(1).max(700),
  suggestedActionText: z.string().trim().min(1).max(220)
});

export type ReflectRequest = z.infer<typeof reflectRequestSchema>;
export type DeepSeekResponsePayload = z.infer<typeof deepseekResponseSchema>;
