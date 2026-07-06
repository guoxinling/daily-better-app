import { issueDeviceToken } from "../lib/tokens.js";

type JsonValue = boolean | number | string | null | JsonValue[] | { [key: string]: JsonValue };

type VercelRequestLike = {
  method?: string;
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

  const token = await issueDeviceToken();
  res.status(200).json(token);
}
