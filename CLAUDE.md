# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

Decent Digest is a native iPhone app that shows a calm daily digest: weather, calendar events, Apple Reminders to-dos, RSS news and new podcast episodes on one page. See `README.md` for the principles.

## Hard constraints

- **iPhone only.** Swift 6, SwiftUI, iOS 26 minimum, portrait.
- **No server.** All work happens on the device. Sync goes through the user's private iCloud (CloudKit private database) only.
- **No analytics or tracking.** No analytics SDKs, no usage events sent anywhere.
- **No paid services or APIs.** Nothing that adds running cost.
- **No AI features.** Do not add Foundation Models or other model calls.
- **Read live, don't copy.** Calendar and Reminders data come from EventKit at display time and are never stored. Feed items show headlines and links; never copy full article text into the app.
- **Window onto other apps.** Checking off a to-do writes back to Reminders. Podcast episodes open in Apple Podcasts. Title-only news items open in Safari.
- **Every permission is optional.** The app must work when calendar, reminders or location access is declined.
- **https feeds only.**
- **Dependencies:** keep them minimal. Ask before adding a package.

## Layout

- `DecentDigest/` is the app target. Xcode syncs this folder automatically, so new files placed here are picked up without editing the project file.
  - `App/` app entry point
  - `Digest/` the digest screen and its section views
  - `Design/Theme.swift` colors, type and spacing
  - `Assets.xcassets` app icon and accent color
- `Packages/DigestCore/` is a local Swift package with models and services and no UI. Put logic here so it can be tested with `swift test`.
  - `Models/` digest models, `ItemStatus`, `ItemID`
  - `FeedLibrary/` loader for `Resources/feed-library.json`
  - `Sample/` sample digest for previews
- `design/app-icon/` icon source SVGs.

## Building and testing

- Open `DecentDigest.xcodeproj` and run the **DecentDigest** scheme.
- Core tests: `cd Packages/DigestCore && swift test` (Swift Testing).
- Bundle ID: `com.decentdigest.app`. Signing uses the developer's own team; never commit a `DEVELOPMENT_TEAM` value or anything under `xcuserdata/`.

## Data model rules

- Feed item ids are `ItemID.make(feedURL:guidOrLink:)`, a SHA-256 hash. Synced reading state is keyed by it, so never change the formula.
- Item status values: `new`, `read`, `useful` (swipe right), `notRelevant` (swipe left), `ignored` (expired untouched), `unread`. Keep them distinct; they form the user's reading history, which stays on device and in the user's iCloud.
- For CloudKit-synced SwiftData models: every property optional or defaulted, no unique constraints, no required relationships.

## Design rules

The look is plain text on a paper page.

- **Colors** (light / dark): page `#FAF9F6` / `#151817`, ink `#1A1D1E` / `#ECEDEA`, secondary `#6F7573` / `#A3A8A5`, rules `#DFE0DC` / `#343937`, accent slate `#3C3C4C` / `#CECED5`. A very faint top-to-bottom page tint. Use the tokens in `Theme.swift`, never raw colors.
- **Type:** Georgia for the date (30pt) and section titles (22pt) only. SF Pro for everything else. Sentence case, never all caps. Support Dynamic Type.
- **Layout:** 24pt side margins, thin 1pt horizontal rules between sections with 24pt above and below, 6pt from section title to list. Compact, not padded.
- **No cards, no section colors, no gradients beyond the page tint, no badges, no unread dots, no counts.** Read vs unread is shown by title weight only.
- **Minimal icons:** no weather icons, no podcast artwork. Lists use gray dash markers.
- **Links and actions** use the slate accent, semibold and underlined.
- **Rows** end in `›` when they open the in-app panel and `↗` when they open another app. The panel is a floating inset sheet in the page color, used only when an item has more than a title.
- **Progressive disclosure:** basics first; one tap opens details; a second tap goes to the source app or site.
- **Motion:** the only decorative animation is a hand-drawn strike-through when an item is checked off or dismissed. Rules stay straight.
- **Accessibility:** VoiceOver labels on every control, sufficient contrast, usable at the largest text size.
