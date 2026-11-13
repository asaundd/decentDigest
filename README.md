# Decent digest

A calm morning digest for iPhone. Weather, calendar, to-dos, news and new podcast episodes on one quiet page.

Decent digest is a window onto the apps you already use. It reads from Calendar, Reminders and the RSS feeds you follow, and hands off to Safari or Podcasts for anything more. It has no server, no account and no analytics, and it is free.

## Principles

- **A window, not a replacement.** Calendar, Reminders and Podcasts stay the source of truth. Small actions, like checking off a to-do, write back to the original app. Anything bigger opens it.
- **Calm.** No badges, unread counts or attention-grabbing colors. Basics first, details one tap deeper.
- **Private.** Everything runs on the device. Data syncs only through the user's own iCloud. No usage data leaves the phone.
- **Near-zero running cost.** No backend and no paid APIs.

## Requirements

- Xcode 26 or later
- iOS 26 or later

## Getting started

1. Open `DecentDigest.xcodeproj` in Xcode.
2. Create `Config/Local.xcconfig` containing one line, `DEVELOPMENT_TEAM = YOURTEAMID`, with your Apple developer team ID. Git ignores this file, so your team stays out of the project. If the bundle ID is taken, change it to something unique to you.
3. Pick an iPhone simulator or a connected iPhone and press **Run** (⌘R).

A short setup on first launch picks what the page shows; every step can be skipped. News comes live from the RSS feeds you follow, picked by topic from a starter library, by name, or by pasting a site's address, and new episodes from the shows you follow, found with Apple's podcast search or picked from Apple Podcasts' current top 12. Calendar and to-dos come live from Calendar and Reminders on the device, once you allow access, and you can leave out any calendar or list; checking off a to-do checks it off in Reminders. Weather comes from Apple's WeatherKit, for your location or a city you pick.

WeatherKit needs a paid Apple Developer Program team. Turn on WeatherKit for your bundle ID in the developer portal (under both Capabilities and App Services), then add `CODE_SIGN_ENTITLEMENTS = Config/WeatherKit.entitlements` to `Config/Local.xcconfig`. Until then the app still runs, and debug builds show sample weather.

Run the core package tests from the command line:

```sh
cd Packages/DigestCore && swift test
```

## Project layout

| Path | What it holds |
| --- | --- |
| `DecentDigest/` | The SwiftUI app: screens, theme, asset catalog |
| `Packages/DigestCore/` | Models and services with no UI, plus the bundled starter feed library |
| `design/app-icon/` | App icon sources (light, dark, tinted) |
