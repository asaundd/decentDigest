# Decent digest

A front page for your day. Decent digest brings your weather, calendar, reminders, news, and podcasts together on one page, from the Apple apps you already use.

It's a window onto those apps, not a replacement. It reads from Calendar, Reminders, and the RSS feeds and podcasts you follow, and hands off to Safari or Podcasts for anything more. It has no server, no account, and no analytics, and it's free.

Website: [decentdigest.com](https://decentdigest.com)

## Principles

- **A window, not a replacement.** Calendar, Reminders, and Podcasts stay the source of truth. Small actions, like checking off a to-do, write back to the original app. Anything bigger opens it.
- **Quiet.** No badges, unread counts, or attention-grabbing colors. Basics first, details one tap deeper.
- **Private.** Everything runs on the device. Data syncs only through the user's own iCloud. No usage data leaves the device.
- **Near-zero running cost.** No backend and no paid APIs.

## Requirements

- Xcode 26 or later
- iOS 26 or later

## Getting started

1. Open `DecentDigest.xcodeproj` in Xcode.
2. Create `Config/Local.xcconfig` containing one line, `DEVELOPMENT_TEAM = YOURTEAMID`, with your Apple developer team ID. Git ignores this file, so your team stays out of the project. If the bundle ID is taken, change it to something unique to you.
3. Pick an iPhone simulator or a connected iPhone and press **Run** (⌘R).

A short setup on first launch picks what the page shows, and every step can be skipped. News comes live from the RSS feeds you follow, picked by topic from a starter library, by name, or by pasting a site's address. New episodes come from the shows you follow, found with Apple's podcast search or picked from Apple Podcasts' current top 12. Calendar and to-dos come live from Calendar and Reminders on the device once you allow access, and you can leave out any calendar or list. Checking off a to-do checks it off in Reminders. Weather comes from Apple's WeatherKit, for your location or a city you pick.

WeatherKit and iCloud sync need a paid Apple Developer Program team. Turn on WeatherKit for your bundle ID in the developer portal (under both Capabilities and App Services), then add `CODE_SIGN_ENTITLEMENTS = Config/WeatherKit.entitlements` to `Config/Local.xcconfig`. That file also turns on iCloud with the container `iCloud.com.decentdigest.app`, so change it to a container of your own. Until then the app still runs, keeps its data on the device, and debug builds show sample weather.

In debug builds, the launch argument `-demo` fills every section with sample content, kept in memory, without reading or changing your own data.

Run the core package tests from the command line:

```sh
cd Packages/DigestCore && swift test
```

## Project layout

| Path | What it holds |
| --- | --- |
| `DecentDigest/` | The SwiftUI app: screens, theme, and asset catalog |
| `Packages/DigestCore/` | Models and services with no UI, plus the bundled starter feed library |
| `design/app-icon/` | App icon sources (light, dark, and tinted) |

## License

Copyright © 2026 Allen Saunders. The code is released under the [MIT License](LICENSE).

The name Decent digest and the app icon identify the app on the App Store. Please use your own name and icon for anything you build from this code.
