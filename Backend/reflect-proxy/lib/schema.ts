import { z } from "zod";

const boundedReflection = z
  .string()
  .trim()
  .min(1)
  .max(700)
  .superRefine((value, context) => {
    const sentences = sentenceCount(value);
    if (sentences < 2 || sentences > 4) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: "reflectionText must contain 2 to 4 sentences"
      });
    }

    if (wordCount(value) > 90) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: "reflectionText must contain at most 90 words"
      });
    }
  });

const boundedAction = z
  .string()
  .trim()
  .min(1)
  .max(220)
  .refine((value) => wordCount(value) <= 35, {
    message: "suggestedActionText must contain at most 35 words"
  });

export const reflectRequestSchema = z
  .object({
    deviceToken: z.string().trim().min(1).max(2048),
    requestId: z.string().trim().uuid(),
    mood: z.enum(["bright", "calm", "okay", "low", "anxious", "overwhelmed"]),
    noteText: z.string().trim().min(1).max(4000),
    locale: z.string().trim().min(2).max(32),
    appVersion: z.string().trim().min(1).max(32)
  })
  .strict();

export const deepseekResponseSchema = z
  .object({
    reflectionText: boundedReflection,
    suggestedActionText: boundedAction
  })
  .strict();

export type ReflectRequest = z.infer<typeof reflectRequestSchema>;
export type DeepSeekResponsePayload = z.infer<typeof deepseekResponseSchema>;

function sentenceCount(value: string): number {
  return value.match(/[.!?。！？]+/gu)?.length ?? 0;
}

function wordCount(value: string): number {
  return value.match(/[\p{L}\p{N}][\p{L}\p{M}\p{N}'’-]*/gu)?.length ?? 0;
}
