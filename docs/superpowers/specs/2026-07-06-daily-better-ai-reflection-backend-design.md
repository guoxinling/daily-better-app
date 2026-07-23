# Daily Better AI Reflection Backend Design

## Goal

Enable real text-based AI reflection in Daily Better while preserving the current local-first product model:

- mood-only reflection remains on-device
- written reflection uses a minimal Vercel backend proxy
- Timeline data remains on-device
- server storage is limited to anonymous operational metrics

This design extends the shipped Check In + Timeline flow without introducing accounts, chat history, or long-term cloud storage.

## Product Scope

This increment adds only the written reflection path.

Included:

- Real remote AI reflection for entries with note text
- Anonymous device token issuance
- Backend token validation and rate limiting
- DeepSeek-backed structured reflection generation
- Timeline row truncation for long notes
- Entry detail presentation of full note, reflection, and suggested action

Excluded:

- Accounts
- Full Timeline sync
- Voice input
- Cross-entry analysis
- Reports
- Global AI toggle
- Safety routing in this increment

## Product Decisions

- Backend platform: `Vercel`
- Model provider: `DeepSeek`
- Model: `deepseek-v4-flash`
- Mode: `non-thinking`
- Abuse control: anonymous device token plus server-side rate limiting
- Server retention: anonymous usage metrics only
- No first-use explicit AI consent modal
- Mood-only reflections continue using the existing local provider
- Timeline list rows show note summaries only, truncated to three lines
- Full reflection content is visible only in entry detail

## User Flow

### Mood Only

If the user selects a mood and leaves the note empty:

1. Tapping `Reflect` uses the local reflection provider
2. The result is saved locally
3. The Reflection screen opens
4. No network request is made

### Mood Plus Text

If the user selects a mood and enters note text:

1. Tapping `Reflect` trims the note and builds a reflection request
2. The app ensures a valid anonymous `deviceToken` exists
3. The app sends the request to `POST /api/reflect`
4. The backend validates the token, enforces rate limits, and calls DeepSeek
5. The backend returns a structured reflection payload
6. The app saves the entry locally with `reflectionSource = ai`
7. The Reflection screen opens

### Failure Path

If remote reflection fails:

1. The current draft remains visible
2. No local entry is saved automatically
3. The app shows `Couldn't reflect right now`
4. The user can choose `Try again` or `Save without reflection`

## Information Architecture Changes

### Timeline Row

Timeline row content becomes summary-only:

- time
- mood
- note preview
- optional lightweight reflection-exists indicator

Rules:

- user note is limited to three visible lines
- overflow uses standard truncation with ellipsis
- reflection text is not rendered in the list row
- suggested action is not rendered in the list row

### Entry Detail

Entry detail becomes the full reading surface for saved entries.

It must show:

- created time
- mood
- full saved note text, if present
- full reflection text, if present
- suggested action text, if present
- reflection source context only if needed for diagnostics or future UX

This preserves scanning speed in Timeline while keeping full entry review available.

## Client Architecture

The existing provider boundary remains in place.

### Existing Boundary

- `CheckInViewModel`
- `ReflectionProviding`
- `LocalReflectionProvider`
- `UnavailableRemoteReflectionProvider`

### New Client Components

Add:

- `DeepSeekRemoteReflectionProvider`
- `DeviceTokenStore`
- `ReflectionAPIClient`

Responsibilities:

- `DeviceTokenStore`
  - securely persist the anonymous device token
  - expose token read, write, and expiry checks
- `ReflectionAPIClient`
  - issue backend HTTP requests
  - decode structured responses
  - retry token bootstrap once if token is missing or expired
- `DeepSeekRemoteReflectionProvider`
  - map `ReflectionRequest` into API payloads
  - convert API success and failure into `ReflectionResult` and `ReflectionError`

### Client Data Rules

- The app never stores provider credentials
- The app never uploads the full Timeline
- The app only sends:
  - current mood
  - current trimmed note
  - locale
  - request ID
  - app version
  - anonymous device token

## Backend Architecture

The backend is a minimal request proxy, not an application server.

### Routes

#### `POST /api/device-token`

Purpose:

- issue an anonymous signed device token

Response:

- `deviceToken`
- `issuedAt`
- `expiresAt`

The token is anonymous and not tied to an account.

#### `POST /api/reflect`

Purpose:

- validate the token
- validate request fields
- enforce rate limits
- call DeepSeek
- validate structured model output
- return the final reflection payload

Request body:

- `deviceToken: String`
- `requestId: String`
- `mood: String`
- `noteText: String`
- `locale: String`
- `appVersion: String`

Success response:

- `reflectionText: String`
- `suggestedActionText: String`
- `source: "ai"`

Error responses:

- `400` invalid request
- `401` invalid or expired token
- `429` rate limited
- `502` provider failure or invalid model response

## Device Token Design

The token exists only to support anonymous abuse control.

Requirements:

- signed by the backend
- opaque to the client
- expiration included
- renewable without user friction

Client behavior:

- fetch token if missing
- refresh token if expired
- on first `401`, fetch a new token once and retry the reflection request once
- if retry still fails, surface normal reflection failure

## Rate Limiting

Minimum first release limits:

- per device token: 10 requests per hour
- per device token: 30 requests per day
- per IP: 30 requests per hour

Behavior:

- limits apply only to remote written reflections
- local mood-only reflections are never rate limited
- when over limit, return `429`
- the iOS app maps this to the same user-facing failure surface used for temporary unavailability

This keeps the UX simple while protecting model spend.

## DeepSeek Request Contract

The backend calls DeepSeek with `deepseek-v4-flash` in `non-thinking` mode.

The prompt must force JSON-only output with exactly:

- `reflectionText`
- `suggestedActionText`

### Content Rules

`reflectionText` must:

- contain 2 to 4 short sentences
- stay under roughly 90 words
- sound calm, specific, and non-clinical
- reflect signals from the current text without claiming certainty
- avoid diagnosis, treatment, medical advice, scoring, or false authority

`suggestedActionText` must:

- be one concrete, low-risk next step
- stay under roughly 35 words
- avoid therapy-style prescriptions or anything high stakes

### Output Validation

The backend must reject model output if:

- required fields are missing
- fields are not strings
- content is empty after trimming
- the payload is materially over length

Rejected output becomes a stable backend failure instead of leaking malformed text to the app.

## Metrics and Retention

The backend stores anonymous metrics only.

Allowed fields:

- `requestId`
- `deviceTokenHash`
- `timestamp`
- `appVersion`
- `latencyMs`
- `providerModel`
- `promptTokens`
- `completionTokens`
- `success`
- `errorCode`

Forbidden:

- note text
- reflection text
- suggested action text
- raw request bodies
- raw provider responses

## Privacy and Disclosure

Because there is no explicit first-use AI consent in this increment, privacy disclosure must be clear in product copy.

At minimum:

- `Settings -> How reflections work` must state that written entries are sent to an AI service to generate a one-time reflection
- privacy policy must reflect the actual backend data flow
- App Store privacy answers must be rechecked before release

This is weaker than explicit consent and should be treated as a conscious product tradeoff.

## Failure Handling

### Client-Side Behavior

- preserve draft on remote failure
- preserve draft on malformed response
- preserve draft on save failure
- allow retry
- allow save without reflection

### Backend Behavior

- invalid input: reject early
- invalid token: `401`
- expired token: `401`
- limit exceeded: `429`
- provider failure: `502`
- invalid model output: `502`

The backend should return stable machine-readable error codes so the client can distinguish retryable categories later, even if the current UI still uses one shared failure alert.

## Testing Strategy

### iOS Unit Tests

Add or extend tests for:

- device token bootstrap
- token refresh on expiry
- one-time retry after token failure
- successful remote reflection persistence
- failed remote reflection preserving draft
- long note Timeline truncation behavior at the view level if practical

### iOS UI Tests

Add or extend tests for:

- text entry plus reflect opens Reflection screen on success
- Timeline row truncates long note text
- entry detail shows full note text
- entry detail shows saved reflection text
- entry detail shows suggested action text

### Backend Tests

Add tests for:

- token issuance
- token validation success and failure
- rate limit success and rejection
- DeepSeek response validation
- invalid model JSON handling
- metric recording without content persistence

## Rollout Strategy

Implement in two code tracks, but keep one release branch:

1. iOS UI and data presentation changes
2. backend proxy plus real remote provider integration

This order allows the product surface to stabilize before wiring live AI traffic.

## Risks

### Privacy Risk

No explicit AI consent reduces friction but increases disclosure sensitivity. Product copy and privacy policy must be precise.

### Cost Risk

If rate limits are too loose, abuse can consume model budget quickly.

### Reliability Risk

Model output may drift. Strict JSON validation on the backend is mandatory.

### UX Risk

If reflection latency is high, the feature will feel fragile. The non-thinking mode choice is intended to minimize this risk.

## Success Criteria

This increment is successful when:

- text-based reflection works end-to-end through Vercel and DeepSeek
- drafts are preserved on failure
- Timeline remains readable with long notes
- detail view exposes the full saved reflection content
- no user text or reflection content is stored on the server
