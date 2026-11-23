# Decent digest

A front page for your day. Decent digest is an iPhone app that puts your weather, calendar, to-dos, news, and podcasts on one page.

It works with the Apple apps you already use. Events come from Calendar and to-dos from Reminders, and episodes open in Apple Podcasts.

There's no account, no server, and no tracking. Your data stays on your phone and in your own iCloud. The app is free.

Website: [decentdigest.com](https://decentdigest.com)

## Principles

- Calendar, Reminders, and Podcasts remain the source of truth. Decent digest shows what's in them and links you to the source apps for more.
- Nothing competes for your attention. No badges, unread counts, or bright colors.
- One tap shows more detail. A second tap takes you to the app or site.
- Nothing leaves your phone except through your own iCloud.
- No backend and no paid services, so it costs almost nothing to run.

## Getting started

You need Xcode 26 and an iPhone or simulator on iOS 26.

1. Open `DecentDigest.xcodeproj`.
2. Create `Config/Local.xcconfig` with one line: `DEVELOPMENT_TEAM = YOURTEAMID`. Git ignores this file. If the bundle ID is taken, change it.
3. Press Run.

Weather and iCloud sync need a paid Apple developer account. Turn on WeatherKit for your bundle ID (under both Capabilities and App Services), then add `CODE_SIGN_ENTITLEMENTS = Config/WeatherKit.entitlements` to `Local.xcconfig`, and change the iCloud container in that file to one of your own. Until then the app still runs, keeps everything on the device, and shows sample weather in debug builds.

To fill the page with sample content without touching your own data, launch a debug build with `-demo`.

To run the tests: `cd Packages/DigestCore && swift test`

## What's where

| Path | Contents |
| --- | --- |
| `DecentDigest/` | The app: screens, theme, and assets |
| `Packages/DigestCore/` | Models and services, plus the starter feed library |
| `design/app-icon/` | App icon sources |

## License

Copyright © 2026 Allen Saunders. The code is under the [MIT License](LICENSE). The name and icon are for this app on the App Store, so please use your own for anything you build from it.
