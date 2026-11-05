# Decent Digest

A calm morning digest for iPhone. Weather, calendar, to-dos, news and new podcast episodes on one quiet page.

Decent Digest is a window onto the apps you already use. It reads from Calendar, Reminders and the RSS feeds you follow, and hands off to Safari or Podcasts for anything more. It has no server, no account and no analytics, and it is free.

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

News comes live from a starter set of RSS feeds. Weather, calendar, to-dos and podcasts still show sample content.

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
