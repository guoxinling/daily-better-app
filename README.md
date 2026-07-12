# Daily Better

Daily Better is a private emotional journal for short everyday check-ins.

- Choose one mood and optionally write what is happening.
- Save multiple private entries each day.
- Review entries through a week-based Timeline.
- Use one optional local reminder at a time you choose.
- No account or cloud Timeline sync.

## AI Reflections

Mood-only reflections are generated on-device.

If you write text and tap Reflect, Daily Better sends only the current mood, current written note, locale, request identifier, app version, and an anonymous device token to the Daily Better reflection service to generate a one-time response.

Timeline history remains on-device.

## Local AI Reflection Development

Use this flow when developing or debugging written AI reflections locally.

### 1. Prepare backend environment variables

Edit:

`/Users/guoxl/Documents/Playground/DailyBetter/.worktrees/ai-emotional-journal/Backend/reflect-proxy/.env.local`

Required keys:

```env
DEVICE_TOKEN_SECRET=replace-with-a-random-string-at-least-32-characters
DEEPSEEK_API_KEY=replace-with-your-real-deepseek-key
DEEPSEEK_MODEL=deepseek-v4-flash
```

Generate a valid token secret with:

```bash
openssl rand -base64 32
```

### 2. Start the local reflect backend

```bash
cd /Users/guoxl/Documents/Playground/DailyBetter/.worktrees/ai-emotional-journal/Backend/reflect-proxy
set -a; source .env.local; set +a; vercel dev --listen 127.0.0.1:3000
```

Expected output:

```text
Ready! Available at http://127.0.0.1:3000
```

### 3. Point the iOS app at the local backend

In Xcode, add this Run Scheme environment variable:

- `DAILYBETTER_REFLECTION_BASE_URL = http://127.0.0.1:3000`

Path:

- `Product -> Scheme -> Edit Scheme... -> Run -> Arguments -> Environment Variables`

### 4. Verify backend endpoints before opening the app

Check device token issuance:

```bash
curl -X POST http://127.0.0.1:3000/api/device-token
```

Check text reflection:

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

### 5. Validate app behavior in the simulator

Verify all three paths:

1. Mood only:
   Local reflection still works without contacting the backend.
2. Mood plus text, backend running:
   The app returns an AI reflection.
3. Mood plus text, backend stopped:
   The app shows `Couldn't reflect right now`, keeps the note text, keeps the selected mood, and allows retry.

## Repo Workflow

- `main`: production-ready code only.
- `feature/*`: one focused feature or change.
- `release/*`: release preparation branch.
- `hotfix/*`: urgent production fixes.

## Versioning

- Marketing version (`MARKETING_VERSION`) tracks the public app version.
- Build number (`CURRENT_PROJECT_VERSION`) increments on every uploaded build.
- Every shipped App Store version should have a matching Git tag.

Current live baseline:

- App Store version: `1.0.0`
- Build: `1`
- Suggested Git tag: `v1.0.0`

## Release Discipline

Before every App Store submission:

1. Update `CHANGELOG.md`.
2. Run a local build.
3. Verify critical flows manually.
4. Confirm metadata/screenshots if they changed.
5. Tag the release commit before upload.
