import { getConfig } from "./config.js";
import { deepseekResponseSchema, type ReflectRequest } from "./schema.js";

const SYSTEM_PROMPT = `
You write calm, specific emotional reflections for a journaling app.
Return JSON only with exactly two string fields:
- reflectionText
- suggestedActionText

Rules for reflectionText:
- 2 to 4 short sentences
- under 90 words
- calm, specific, non-clinical
- reflect signals from the current text without diagnosing
- no medical advice, therapy claims, scoring, or authority language

Rules for suggestedActionText:
- one concrete, low-risk next step
- under 35 words
- no high-stakes advice
`.trim();

type DeepSeekUsage = {
  prompt_tokens?: number;
  completion_tokens?: number;
};

type DeepSeekResult = {
  reflectionText: string;
  suggestedActionText: string;
  providerModel: string;
  promptTokens?: number;
  completionTokens?: number;
};

type FetchLike = typeof fetch;

export class InvalidModelPayloadError extends Error {
  constructor(public readonly code = "invalid_model_payload") {
    super(code);
    this.name = "InvalidModelPayloadError";
  }
}

export class ProviderUnavailableError extends Error {
  constructor(public readonly code = "provider_unavailable") {
    super(code);
    this.name = "ProviderUnavailableError";
  }
}

export async function requestReflectionFromDeepSeek(
  input: ReflectRequest,
  fetchImpl: FetchLike = fetch
): Promise<DeepSeekResult> {
  const config = getConfig();
  if (!config.DEEPSEEK_API_KEY) {
    throw new ProviderUnavailableError("missing_deepseek_api_key");
  }

  const response = await fetchImpl("https://api.deepseek.com/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${config.DEEPSEEK_API_KEY}`
    },
    body: JSON.stringify({
      model: config.DEEPSEEK_MODEL,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: JSON.stringify({
            mood: input.mood,
            noteText: input.noteText,
            locale: input.locale
          })
        }
      ],
      thinking: { type: "disabled" },
      response_format: { type: "json_object" }
    })
  });

  if (!response.ok) {
    throw new ProviderUnavailableError(`deepseek_status_${response.status}`);
  }

  const payload = (await response.json()) as {
    model?: string;
    usage?: DeepSeekUsage;
    choices?: Array<{ message?: { content?: string | null } }>;
  };

  const content = payload.choices?.[0]?.message?.content;
  if (typeof content !== "string" || content.trim().length === 0) {
    throw new InvalidModelPayloadError();
  }

  let parsedContent: unknown;
  try {
    parsedContent = JSON.parse(content);
  } catch {
    throw new InvalidModelPayloadError("invalid_model_json");
  }

  const parsed = deepseekResponseSchema.safeParse(parsedContent);
  if (!parsed.success) {
    throw new InvalidModelPayloadError();
  }

  return {
    reflectionText: parsed.data.reflectionText,
    suggestedActionText: parsed.data.suggestedActionText,
    providerModel: payload.model ?? config.DEEPSEEK_MODEL,
    promptTokens: payload.usage?.prompt_tokens,
    completionTokens: payload.usage?.completion_tokens
  };
}
