# Release Checklist

Use this checklist before every App Store submission.

## Versioning

- [ ] `MARKETING_VERSION` matches the intended release version.
- [ ] `CURRENT_PROJECT_VERSION` is higher than the last uploaded build.
- [ ] `CHANGELOG.md` is updated.
- [ ] A release branch exists if the release is not a hotfix.

## Product Validation

- [ ] App builds successfully in Release configuration.
- [ ] Today screen works as expected.
- [ ] Mood logging and mood history still work.
- [ ] Custom affirmations save and display correctly.
- [ ] Reminder settings can still be changed without breaking notifications.
- [ ] Existing local data still loads after the update.

## App Store Readiness

- [ ] Screenshots are current if UI changed.
- [ ] Metadata is current if naming or copy changed.
- [ ] Privacy answers still match the shipped code.
- [ ] Support and privacy URLs are still live.

## Git Traceability

- [ ] Release commit is merged to `main`.
- [ ] A Git tag is created for the release.
- [ ] The App Store version, build number, Git tag, and commit hash are recorded together.

