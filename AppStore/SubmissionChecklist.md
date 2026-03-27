# Daily Better Submission Checklist

## Current Submission Baseline
- App name: Daily Better
- Bundle identifier: com.guoxl.DailyBetter
- Version: 1.0.0
- Category: Health & Fitness
- Build verified in Simulator: yes

## Apple Requirements To Fill In
- Support URL is required in platform version information.
- Privacy Policy URL is required for iOS apps.
- At least one iPhone screenshot is required.
- If you keep iPad support enabled, at least one iPad screenshot is required.

## What Is Already Prepared In This Folder
- Metadata draft: `Metadata.md`
- Privacy policy draft: `PrivacyPolicy.md`
- Support page draft: `Support.md`
- Screenshot script: `../Tools/capture_screenshots.sh`

## Manual Steps In Xcode
1. Open the project and set your Apple Developer Team.
2. Confirm the final bundle identifier you want to ship.
3. Archive with a device build.
4. Upload the archive to App Store Connect.

## Manual Steps In App Store Connect
1. Create or open the app record.
2. Paste the app name, subtitle, description, keywords, and review notes from `Metadata.md`.
3. Add your live Support URL.
4. Add your live Privacy Policy URL.
5. Answer App Privacy questions.
6. Upload screenshots from `Screenshots/iPhone-6.9` and `Screenshots/iPad-13`.
7. Set the age rating.
8. Add review contact details.
9. Submit for review.

## Notes For This Build
- The current app stores data locally on-device.
- The current app does not require sign-in.
- The current app only requests notification permission for optional reminders.
- If you do not want to provide iPad screenshots, remove iPad from the supported device family before shipping.
