# Daily Better Reflect Proxy

This backend issues anonymous device tokens and generates written AI reflections for the Daily Better iOS app.

## Local setup

Create or edit:

`/Users/guoxl/Documents/Playground/DailyBetter/.worktrees/ai-emotional-journal/Backend/reflect-proxy/.env.local`

Required values:

```env
DEVICE_TOKEN_SECRET=replace-with-a-random-string-at-least-32-characters
DEEPSEEK_API_KEY=replace-with-your-real-deepseek-key
DEEPSEEK_MODEL=deepseek-v4-flash
```

Generate a token secret with:

```bash
openssl rand -base64 32
```

## Run locally

```bash
cd /Users/guoxl/Documents/Playground/DailyBetter/.worktrees/ai-emotional-journal/Backend/reflect-proxy
set -a; source .env.local; set +a; vercel dev --listen 127.0.0.1:3000
```

Expected output:

```text
Ready! Available at http://127.0.0.1:3000
```

## Test locally

Issue a device token:

```bash
curl -X POST http://127.0.0.1:3000/api/device-token
```

Use the returned token to request a reflection:

```bash
curl -X POST http://127.0.0.1:3000/api/reflect \
  -H 'Content-Type: application/json' \
  -d '{
    "deviceToken": "paste-a-device-token-here",
    "requestId": "11111111-1111-1111-1111-111111111111",
    "appVersion": "1.0",
    "locale": "en_US",
    "mood": "anxious",
    "noteText": "I feel overloaded today and cannot focus."
  }'
```

## Expected behavior

- `/api/device-token` returns `deviceToken`, `issuedAt`, and `expiresAt`
- `/api/reflect` returns:
  - `reflectionText`
  - `suggestedActionText`
  - `source: "ai"`

## Common failure cases

- `DEVICE_TOKEN_SECRET` missing or too short:
  local function boot fails before issuing a token
- `DEEPSEEK_API_KEY` missing:
  reflection requests fail with provider errors
- Wrong request body:
  use `locale`, not `localeIdentifier`
- Backend stopped:
  the iOS app should show `Couldn't reflect right now` and keep the current draft
