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
