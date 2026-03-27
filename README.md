# Daily Better

`Daily Better` is a lightweight iOS app for daily affirmations and emoji-based mood check-ins.

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

