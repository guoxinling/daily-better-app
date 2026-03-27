# Versioning and Rollback

## Branch Model

- `main`
  Production-ready code only.
- `feature/<short-name>`
  One scoped change at a time.
- `release/<version>`
  Stabilization branch before an App Store submission.
- `hotfix/<version>-<short-name>`
  Emergency fix for a live issue.

Examples:

- `feature/custom-priority`
- `feature/daily-widget`
- `release/1.1.0`
- `hotfix/1.0.1-reminder-copy`

## Version Rules

- Patch (`1.0.1`): bug fixes and low-risk polish.
- Minor (`1.1.0`): new features without a major redesign.
- Major (`2.0.0`): large product or architecture changes.

Build number rules:

- Increment for every uploaded App Store Connect build.
- Do not reuse old build numbers.

## Release Mapping

Each shipped release should map these four items together:

- App Store version
- App Store build number
- Git tag
- Git commit hash

## Rollback Reality

Git rollback and App Store rollback are different:

- Git rollback: easy, revert to a known tag or commit.
- App Store rollback: usually handled by shipping a hotfix update, pausing phased release, or removing the app from sale if needed.

Recommended production safety habits:

- Use manual release or phased release for risky updates.
- Keep hotfix branches small and focused.
- Avoid mixing multiple unrelated changes in one release.

