# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

Decent Digest is a native iPhone app that shows a calm daily digest: weather, calendar events, Apple Reminders to-dos, RSS news and new podcast episodes on one page. See `README.md` for the principles.

## Hard constraints

- **iPhone only.** Swift 6, SwiftUI, iOS 26 minimum, portrait.
- **No server.** All work happens on the device. Sync goes through the user's private iCloud (CloudKit private database) only.
- **No analytics or tracking.** No analytics SDKs, no usage events sent anywhere.
- **No paid services or APIs.** Nothing that adds running cost. Weather comes from WeatherKit's free quota, which requires the Apple Weather mark and legal link in the footer. Apple's public iTunes lookup (no key) finds an episode's Apple Podcasts page, only when Open ↗ is tapped.
- **No AI features.** Do not add Foundation Models or other model calls.
- **Read live, don't copy.** Calendar and Reminders data come from EventKit at display time and are never stored. The last forecast and place are cached on the device only, so the page opens with weather. The app never fetches article pages. When a feed itself carries the full post, that text is cached on the device only (never synced) and leaves with the cached item.
- **Window onto other apps.** Checking off a to-do writes back to Reminders. Podcast episodes open in Apple Podcasts. Title-only news items open in Safari.
- **Every permission is optional.** The app must work when calendar, reminders or location access is declined.
- **https feeds only.**
- **Dependencies:** keep them minimal. Ask before adding a package.

## Layout

- `DecentDigest/` is the app target. Xcode syncs this folder automatically, so new files placed here are picked up without editing the project file.
  - `App/` app entry point
  - `Digest/` the digest screen and its section views (`FeedListSection` draws both News and Podcasts)
  - `Weather/` the weather lines under the date and Settings › Weather
  - `Design/Theme.swift` colors, type and spacing
  - `Assets.xcassets` app icon and accent color
- `Packages/DigestCore/` is a local Swift package with models and services and no UI. Put logic here so it can be tested with `swift test`.
  - `Models/` digest models, `ItemStatus`, `ItemID`
  - `Agenda/` Calendar and Reminders through EventKit (`EventKitSource`), the rules for what each section shows, and `AgendaModel`, which the UI observes
  - `FeedLibrary/` loader for `Resources/feed-library.json`
  - `Feeds/` feed fetching and parsing (RSS 2.0, RSS 1.0, Atom), HTML-to-text, news list rules
  - `Weather/` forecast models, `WeatherRules` (today in a few words, the "what changes next" line), `WeatherModel`, which the UI observes, `WeatherKitSource` and `LocationPlaces` (iOS only)
  - `Podcasts/` `PodcastRules` (episode length, a new show's first fetch) and `ApplePodcasts` (finds an episode's Apple Podcasts link)
  - `Store/` SwiftData models, container setup, `FeedStore` (the background writer for fetched feeds) and `ReadingState` (item status writes from the UI)
  - `Sample/` sample digest, weather and places for previews and tests
- `design/app-icon/` icon source SVGs.

## Building and testing

- Open `DecentDigest.xcodeproj` and run the **DecentDigest** scheme.
- Core tests: `cd Packages/DigestCore && swift test` (Swift Testing).
- Bundle ID: `com.decentdigest.app`. Signing uses the developer's own team, set in `Config/Local.xcconfig` (git-ignored, included by `Config/Signing.xcconfig`). Never commit a `DEVELOPMENT_TEAM` value or anything under `xcuserdata/`.
- WeatherKit needs a paid developer team with WeatherKit turned on for the bundle ID (Capabilities and App Services). Then `CODE_SIGN_ENTITLEMENTS = Config/WeatherKit.entitlements` goes in `Local.xcconfig`. Without it the app still builds, and debug builds show sample weather with a note.

## Data model rules

- Feed item ids are `ItemID.make(feedURL:guidOrLink:)`, a SHA-256 hash. Synced reading state is keyed by it, so never change the formula.
- Item status values: `new`, `read`, `useful` (swipe right, shown as "Relevant"), `notRelevant` (swipe left, shown as "Not relevant"), `ignored` (expired untouched), `unread`, `saved` (in Saved, never expires). Keep them distinct; they form the user's reading history, which stays on device and in the user's iCloud.
- For CloudKit-synced SwiftData models: every property optional or defaulted, no unique constraints, no required relationships.
- News and podcasts share `Source` (`kind` is `news` or `podcast`; a podcast keeps its Apple Podcasts id in `appleID`), `FeedItem`, `ItemState` and `SavedItem` (`kind` says which). Episodes follow the News rules: they leave 7 days after they came out, untouched ones become `ignored`. A source's first fetch starts News at today's items (or yesterday's) and a show at its newest episode from the last 7 days.
- Two stores: `Source`, `ItemState` and `SavedItem` sync through iCloud; `FeedItem` and `FetchState` stay on the device. Models link by id strings, not relationships.

## Design rules

The look is plain text on a paper page.

- **Colors** (light / dark): page `#FAF9F6` / `#151817`, ink `#1A1D1E` / `#ECEDEA`, secondary `#6F7573` / `#A3A8A5`, rules `#DFE0DC` / `#343937`, accent slate `#3C3C4C` / `#CECED5`. A very faint top-to-bottom page tint. Use the tokens in `Theme.swift`, never raw colors.
- **Type:** Georgia for the date (30pt) and section titles (22pt) only. SF Pro for everything else. Sentence case, never all caps. Support Dynamic Type.
- **Layout:** 24pt side margins, thin 1pt horizontal rules between sections with 24pt above and below, 11pt from a section title to the first line of News, Podcasts, Saved, Calendar and To do, 6pt elsewhere. Compact, not padded.
- **No cards (except an open headline), no section colors, no gradients beyond the page tint, no badges, no unread dots, no counts.** The one exception is the quiet gray "N more · Show all" line under News. Unread titles are semibold; opened or seen titles are regular weight in the same ink and leave the list at the next refresh. Acting on an item (useful, not useful, save) removes it at once with no fade; the rows below slide up briefly (0.2s), and a headline joining from "N more" fades in only after the slide, so rows never overlap.
- **Minimal icons:** no weather icons, no podcast artwork. Weather's only symbol is the small gray location arrow after a place that comes from the device's location. Lists use gray dash markers. The only symbols are the bookmark (Save), ✓ and ✕ on the action ribbon and swipe actions (swipes are drawn by hand, not system swipe actions: a light 20pt symbol over a 12pt medium word, Relevant or Not relevant, on the page, pinned to the edge and drawn only in the strip the row has moved off, so the page color never changes. While dragging, a hand-drawn strike crosses the title in step with the swipe; at the threshold the strike is complete, the title turns gray and the symbol and word turn from gray to ink), and ↗ on title-only rows and Open links.
- **Links and actions** use the slate accent, semibold and underlined.
- **Rows** carry no marker, except `↗` on title-only rows (reading those means going to the site). A tap expands any row in place. `PostKind` sorts each post by what the feed sent: Full post (1,500 characters or more with no "continue reading" note), Excerpt (post text that stops short, or text ending in such a note or "…"), Summary (other short text) or Link only. An expanded headline keeps its title in place and shows its details below it on a card a shade lighter than the page (`Theme.expandedFill`), 8pt corners, starting under the dash on the left and reaching 12pt past the text on the right, with a faint edge and shadow. Its top line holds the byline on the left and small square buttons a shade darker than the card on the right, where the thumb is: Save (bookmark), ✓ (relevant) and ✕ (not relevant), with matching VoiceOver labels. (Link-only rows put "No summary available." on that line instead.) Below are up to 320 characters of text, then text actions lined up with the text, whose labels say what the feed sent (Read full post for a full post; Read excerpt and Open ↗ for an excerpt; Open ↗ otherwise). Read full post, Read excerpt, or tapping their text opens the panel: a floating sheet in the card's color that slides in from the right, inset from the edge, showing the full post or the whole excerpt, with an action ribbon pinned at its bottom: Open ↗ first, then the same square buttons on the right. Several rows can be open at once; a row closes only when its title is tapped again. Expanding keeps a title bold until the row is closed or another row is tapped.
- **Calendar and To do:** both are bulleted lists of days (dash, then the day's name in semibold: Today, then weekday names, no dates), items in a slightly lighter ink (`Theme.itemInk`) and a smaller size under each day, with a little more space before each later day. `DayPlanner` decides what shows: at most three days (today, then the next two days that have anything); all of today, at least the first item of the next day, then the third day until 10 items; a cut-off day ends with a plain gray "N more event(s)" or "N more item(s)" that fills the day in when tapped, and a footer like News under the days reads "N more events this week · Show all" (Show less once open), or "No other events this week" when nothing waits. Calendar: times in a 60pt gray column as 9:30a / 2:15p / All day; past events `Theme.past` and struck through; the event happening now has a 2pt slate line at its left (never all-day events); Calendar ↗ in the title row. To do: today holds everything due today plus anything still open from earlier, with "Past due" in gray after the title (the card says which day); then an Anytime group of undated to-dos, up to 5 or more when the days leave room under 10; Reminders ↗ in the title row. A tap makes a row semibold at once (no animation) and opens a card like an open headline (`agendaCard()`), text lined up with the list; a tap on the title or the card closes it. An event's card: length (with "· ends 2:00p" while it runs), place, up to 3 invitees, notes in ink cut at 3 lines without video call links, Open ↗ and Directions ↗ for an address. A to-do's card: due day · list, notes, ✓ at the top right that checks it off in Reminders with the hand-drawn strike and a light haptic, then becomes the undo arrow; the to-do leaves when its card closes. Swiping a closed to-do right also checks it off and it leaves at once. If access was declined, the section is not shown at all; until the app has asked, it shows one gray line and Allow access.
- **Weather:** the page's opening lines under the date, not a titled section; words, never icons. The temperature now (40pt light) beside today in a few words ("Rain after 4p", "Rain until 2p", or the condition) over "High 61° · Low 46°" in gray. Then one gray 14pt line, with no label, on what changes over the next two days compared with today, from `WeatherRules` (plain code, no AI): storms first, then rain or snow starting or stopping, then highs 8°F or more apart, heat (90°F+) or a freeze (32°F or below); it names the day (tomorrow, then the weekday), gives a number only for heat or a freeze, uses one sentence (two at most), and says "Tomorrow and Wednesday look about the same." when nothing changes. The same line then adds one sentence (two at most) on anything notable later in the week (`WeatherRules.weekLine`): in order, storms on a named day, rain or snow starting, heat, a freeze or a turn warmer or colder, then the weekend ("Cold and sunny this weekend."); storms can share the line with one more; nothing when the week is quiet. Show week on its own line at the bottom, left-aligned like Show all (Show less once open, still last), lists the next 6 days: dash, day name semibold, condition and low–high (`44–57°`) in `Theme.itemInk`, 15pt, tabular figures; days don't open. Under the list, one line: "For Brooklyn, NY" in gray, the city with a faint underline and opening Settings › Weather (type a city, or use location, handing off to iOS Settings if declined), a small gray location arrow when the place comes from the device's location, and Weather ↗ on the right, shown only when iOS can open `weather://`. The Apple Weather mark and Legal link sit in the footer. With no location and no typed city the date stands alone; until location has been asked, one gray line and Set up weather. °F or °C follows the device.
- **Podcasts:** one list like News, newest first: the episode title (semibold until opened) over the show's name in gray, no length, age or artwork. Up to 5, then "N more · Show all"; Podcasts ↗ in the title row. A tap opens the same card as a headline, with the length ("58 min") where News puts the byline, then Save, ✓ and ✕; up to 320 characters of show notes; then Read notes (only when there is more; opens the panel) and Open ↗, which opens the episode in Apple Podcasts. Swipes, the strike and read state work as on News.
- **Saved:** saved headlines and episodes, newest saved first; each works like its News or Podcasts row and never expires.
- **Progressive disclosure:** basics first; one tap opens details; a second tap goes to the source app or site.
- **Motion:** the only decorative animation is a hand-drawn strike-through when an item is checked off or dismissed (for headlines, drawn by the swipe itself). Rules stay straight.
- **Accessibility:** VoiceOver labels on every control, sufficient contrast, usable at the largest text size.
