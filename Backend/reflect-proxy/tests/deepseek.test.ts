import { afterEach, beforeEach, expect, test } from "vitest";

import { requestReflectionFromDeepSeek } from "../lib/deepseek.js";
import { resetConfigForTests } from "../lib/config.js";
import { deepseekResponseSchema } from "../lib/schema.js";

beforeEach(() => {
  process.env.DEVICE_TOKEN_SECRET = "test-device-token-secret-value-2026";
  process.env.DEEPSEEK_API_KEY = "test-deepseek-api-key";
  process.env.DEEPSEEK_MODEL = "deepseek-v4-flash";
  resetConfigForTests();
});

afterEach(() => {
  delete process.env.DEVICE_TOKEN_SECRET;
  delete process.env.DEEPSEEK_API_KEY;
  delete process.env.DEEPSEEK_MODEL;
  resetConfigForTests();
});

test("DeepSeek request explicitly disables thinking mode", async () => {
  let capturedBody: Record<string, unknown> | undefined;
  const fetchImpl: typeof fetch = async (_input, init) => {
    capturedBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
    return new Response(
      JSON.stringify({
        model: "deepseek-v4-flash",
        choices: [
          {
            message: {
              content: JSON.stringify({
                reflectionText: "Today sounds heavy. You are still making room to notice it.",
                suggestedActionText: "Take one slow breath before your next task."
              })
            }
          }
        ]
      }),
      { status: 200 }
    );
  };

  await requestReflectionFromDeepSeek(
    {
      deviceToken: "device-token",
      requestId: "11111111-1111-4111-8111-111111111111",
      mood: "low",
      noteText: "I am carrying too much today.",
      locale: "en_US",
      appVersion: "1.2.0"
    },
    fetchImpl
  );

  expect(capturedBody?.thinking).toEqual({ type: "disabled" });
});

test("model response requires two to four reflection sentences", () => {
  expect(
    deepseekResponseSchema.safeParse({
      reflectionText: "Only one sentence.",
      suggestedActionText: "Take one slow breath."
    }).success
  ).toBe(false);

  expect(
    deepseekResponseSchema.safeParse({
      reflectionText: "One. Two. Three. Four. Five.",
      suggestedActionText: "Take one slow breath."
    }).success
  ).toBe(false);
});

test("model response caps reflection at 90 words", () => {
  const words = Array.from({ length: 91 }, (_, index) => `word${index}`).join(" ");

  expect(
    deepseekResponseSchema.safeParse({
      reflectionText: `${words}. A second sentence.`,
      suggestedActionText: "Take one slow breath."
    }).success
  ).toBe(false);
});

test("model response caps suggested action at 35 words", () => {
  const words = Array.from({ length: 36 }, () => "step").join(" ");

  expect(
    deepseekResponseSchema.safeParse({
      reflectionText: "This feeling is present. It does not have to define the whole day.",
      suggestedActionText: `${words}.`
    }).success
  ).toBe(false);
});
