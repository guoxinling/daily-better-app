# Task 2 Report: Create/Edit Persistence Contracts

## Status

DONE

## RED

Command:

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/CheckInRepositoryTests \
  -only-testing:DailyBetterTests/CheckInViewModelTests
```

Result: FAIL, as expected before production implementation. The test target could not compile because `EntryComposerMode` did not exist. The run reported `cannot find type 'EntryComposerMode' in scope` in `CheckInViewModelTests.swift`; no tests executed.

## GREEN

Command:

```bash
xcodegen generate
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/CheckInRepositoryTests \
  -only-testing:DailyBetterTests/CheckInViewModelTests
```

Result: PASS. XcodeGen regenerated `DailyBetter.xcodeproj`, including `EntryComposerMode.swift`. The focused suite executed 19 tests with 0 failures: 4 `CheckInRepositoryTests` and 15 `CheckInViewModelTests`.

## Self-Review

- Added `EntryComposerMode` with create timestamp and edit-entry modes, plus a timestamp-bearing normalized `CheckInDraft` used for edit cancel detection.
- Added `mode`, `hasUnsavedChanges`, and `committedEntry` to the view model. Both save paths use one mode-aware persistence method, and callbacks run before a create draft is cleared.
- Preserved local-provider selection for blank notes and remote-provider selection for written notes.
- Restored repository isolation with a fresh `ModelContext` backed by the caller context's container. Save, update, delete, and delete-all failures therefore do not roll back unrelated caller-context work.
- Update and delete resolve the stored row by stable `CheckInEntry.id`. Update snapshots mutable stored fields, restores and rolls back on failure, and mirrors committed fields to the caller-visible entry only after a successful save.
- `reflection == nil` clears reflection text/action, sets source/status to `.none`, and resets helpfulness to `.unanswered` in both create and edit persistence paths.
- Preserved the existing save/delete failure-safety tests and added update failure coverage proving that both stored data and caller-visible state remain unchanged. Added delete coverage proving exactly one entry is removed.
- Ran `git diff --check`; no whitespace errors were reported. Confirmed the generated project contains `EntryComposerMode.swift` and no unrelated dirty files were staged for commit.

## Concerns

- The intentional read-only-store failure tests emit CoreData and SwiftData permission logs while asserting rollback safety. These logs are expected; all focused tests passed.
