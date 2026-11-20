import Combine
import SwiftUI
import UIKit

/// What Skip for now asks first when something on the step is already chosen.
struct SkipQuestion {
    var title: String
    var message: String
    /// The button that skips, such as "Skip and unfollow".
    var confirm: String
    /// Red, for a skip that undoes something.
    var destructive = true
    /// Runs before skipping, such as unfollowing the picks.
    var undo: () -> Void = {}
}

/// One setup step: ‹ Back and "Step N of 4" at the top, a Charter title over a gray intro, the
/// step's choices, an optional small gray note, then Continue (dimmed until something is chosen)
/// with Skip for now under it.
struct OnboardingStep<Content: View>: View {
    var number: Int
    var title: String
    var intro: String
    var note: String?
    var canContinue: Bool
    /// Asked before skipping; nil skips at once.
    var skipQuestion: SkipQuestion? = nil
    var back: () -> Void
    var skip: () -> Void
    var next: () -> Void
    @ViewBuilder var content: Content

    @State private var asksToSkip = false
    @State private var keyboardShown = false

    var body: some View {
        RevealingScrollView(keyboardShown: $keyboardShown) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    BackLink(action: back)
                    Spacer()
                    Text("Step \(number) of \(OnboardingFlow.stepCount)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
                Text(title)
                    .font(Theme.dateFont)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 20)
                Text(intro)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                content
                    .padding(.top, 20)
                if let note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 24)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.margin)
            .padding(.top, 12)
            .padding(.bottom, Theme.margin)
        }
        // Continue and Skip stay at the bottom of the screen, under the keyboard, so they don't
        // cover search results while typing.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboardShown {
                bottomButtons
            }
        }
        .onboardingPage()
        // The page keeps the app's links color; only the question takes iOS's own.
        .tint(Theme.accent)
        .alert(skipQuestion?.title ?? "", isPresented: $asksToSkip) {
            Button(skipQuestion?.confirm ?? "Skip", role: skipQuestion?.destructive == false ? nil : .destructive) {
                skipQuestion?.undo()
                skip()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(skipQuestion?.message ?? "")
        }
        .tint(Theme.alertTint)
    }

    private var bottomButtons: some View {
            VStack(spacing: 4) {
                PrimaryButton(title: "Continue", isEnabled: canContinue, action: next)
                Button {
                    if skipQuestion != nil { asksToSkip = true } else { skip() }
                } label: {
                    Text("Skip for now")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityHint("Leaves this part off your digest for now")
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(Theme.bottomBarFill)
    }
}

/// A page's scroll view that scrolls a tapped search box up to the top while the keyboard is open,
/// with extra room below so it can, and reports whether the keyboard is showing.
struct RevealingScrollView<Content: View>: View {
    @Binding var keyboardShown: Bool
    @ViewBuilder var content: Content

    @State private var searchReveal = SearchReveal()
    @State private var viewHeight: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
                    // Room to keep the search box at the top while the keyboard is open: a full
                    // screen's worth, so the page never runs short and slides back down when the
                    // results below the box change (as with the first letter typed).
                    .padding(.bottom, keyboardShown ? max(viewHeight, 400) : 0)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewHeight = $0 }
            .scrollDismissesKeyboard(.interactively)
            .environment(searchReveal)
            .onChange(of: searchReveal.requests) { _, _ in
                searchReveal.scroll(proxy)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardShown = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardShown = false
        }
    }
}

/// Lets a search box ask its page to scroll it to the top when it's tapped, leaving room for results
/// between the box and the keyboard. Setup steps and Settings pages put one in the environment and
/// scroll when `requests` changes.
@MainActor
@Observable
final class SearchReveal {
    private(set) var requests = 0
    /// The view to bring to the top: the search box, or a topic that was just opened.
    private(set) var target = SearchBox.scrollID

    func request(_ id: String = SearchBox.scrollID) {
        target = id
        requests += 1
    }

    func scroll(_ proxy: ScrollViewProxy) {
        let target = target
        // After the keyboard starts to rise or the topic opens, so the page knows its new size.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(target, anchor: UnitPoint(x: 0.5, y: 0.02))
            }
        }
    }
}

/// The paper page every setup screen sits on.
extension View {
    func onboardingPage() -> some View {
        foregroundStyle(Theme.ink)
            .tint(Theme.accent)
            .background(
                LinearGradient(colors: [Theme.pageTintTop, Theme.pageTintBottom], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
    }
}

/// "‹ Back" at the top left of a setup step, or "‹ Settings" on a Settings page.
struct BackLink: View {
    var title = "Back"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("‹ \(title)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .padding(.vertical, 8)
                .padding(.trailing, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(title == "Back" ? "Back" : "Back to \(title)")
    }
}

/// The one filled button on a setup screen: full width, slate. Dimmed to a paper shade until it can be used.
struct PrimaryButton: View {
    var title: String
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(isEnabled ? Theme.buttonText : Theme.buttonDimmedText)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    isEnabled ? Theme.buttonFill : Theme.buttonDimmedFill,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!isEnabled)
        .animation(nil, value: isEnabled)
        .accessibilityHint(isEnabled ? "" : "Choose something above first, or skip for now")
    }
}

/// A row in a setup list: a name over an optional gray line on the left, and an action on the right
/// (Allow, ✓ Allowed, Follow, Unfollow, Use).
struct ChoiceRow<Trailing: View>: View {
    var title: String
    var subtitle: String?
    /// Semibold, for a site or show being followed in setup.
    var emphasized = false
    /// A gray dash before the name, in a slightly smaller, lighter type, for sites listed under a topic.
    var dashed = false
    /// Makes the whole row a tap target for the same action as its link, as in search results.
    var onTap: (() -> Void)? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if dashed {
                    Text("–")
                        .foregroundStyle(Theme.secondary)
                        .frame(width: DashColumn.width, alignment: .leading)
                        .accessibilityHidden(true)
                }
                choiceText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        // Dashed rows sit as close as the calendar and Reminders lists.
        .padding(.vertical, dashed ? 4 : 6)
        .modifier(RowTap(action: onTap))
    }

    private var choiceText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(dashed ? .callout : .body)
                .fontWeight(emphasized ? .semibold : .regular)
                .foregroundStyle(dashed ? Theme.itemInk : Theme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A tap anywhere on a row, only when the row has an action, so rows inside a button (a topic)
/// still pass their taps to it.
private struct RowTap: ViewModifier {
    var action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content
                .contentShape(Rectangle())
                .onTapGesture(perform: action)
        } else {
            content
        }
    }
}

/// "✓ In use", "✓ Allowed": a quiet note in place of a link once a choice is made.
struct DoneNote: View {
    var text: String

    var body: some View {
        Text("✓ \(text)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .fixedSize()
            .padding(.vertical, 4)
    }
}

/// Follow (gray blue, semibold), which becomes Unfollow (gray): the link says what a tap does. Neither
/// is underlined: a column of them down a list would read as a web form.
struct FollowLink: View {
    var title: String
    var isFollowing: Bool
    var toggle: () -> Void

    var body: some View {
        if isFollowing {
            QuietLink("Unfollow", action: toggle)
                .accessibilityLabel("Unfollow \(title)")
        } else {
            FooterLink("Follow", still: true, action: toggle)
                .accessibilityLabel("Follow \(title)")
        }
    }
}

/// A link that undoes a choice (Unfollow, Hide): gray and semibold, with no underline, like the
/// Follow and Show it replaces.
struct QuietLink: View {
    var title: String
    /// True for a link whose label changes when tapped: it skips the pressed dimming, which
    /// otherwise fades back in on the new label.
    var still = false
    var action: () -> Void

    init(_ title: String, still: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.still = still
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.actionFont)
                .foregroundStyle(Theme.secondary)
                .fixedSize()
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(QuietLinkStyle(still: still))
    }
}

/// A link at the foot of a section (Show all, Show less, Calendar ↗, Weather's Show week): slate and
/// semibold with no underline, so the only line near a section's end is the rule. Links inside cards
/// and the panel keep their underline (`TextLink`).
struct FooterLink: View {
    var title: String
    /// True for a link whose label changes when tapped (Show all / Show less): it skips the pressed
    /// dimming, which otherwise fades back in on the new label.
    var still = false
    /// True to let a long label wrap onto more lines instead of staying on one.
    var wraps = false
    var action: () -> Void

    init(_ title: String, still: Bool = false, wraps: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.still = still
        self.wraps = wraps
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.actionFont)
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: !wraps, vertical: true)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(QuietLinkStyle(still: still))
    }
}

/// The borderless look, optionally without the pressed dimming.
private struct QuietLinkStyle: PrimitiveButtonStyle {
    var still: Bool

    func makeBody(configuration: Configuration) -> some View {
        if still {
            Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                .buttonStyle(StillButtonStyle())
        } else {
            Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                .buttonStyle(.borderless)
        }
    }
}

/// A filled search box, so it's clear it can be typed in. An ✕ clears it while it holds text. While
/// it's being typed in, Cancel to its right clears it and puts the keyboard away, as do the return
/// key and a drag down on the page. When tapped, it asks
/// its page to scroll it to the top, so results have room above the keyboard.
struct SearchBox: View {
    static let scrollID = "searchBox"

    var placeholder: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var keyboard: UIKeyboardType = .default
    /// The return key's label: Done where results come as you type, Search where return looks
    /// something up.
    var submitLabel: SubmitLabel = .done
    /// Shows Paste beside Cancel while the box is empty, for boxes where pasting is likely.
    var offersPaste = false
    /// Grayed out and not tappable, for a search that needs a connection while offline.
    var isDisabled = false
    /// Scrolls the box to the top of the page when tapped, to leave room for results above the
    /// keyboard. Off where the box already sits near the top (News), so the page stays put.
    var revealsOnFocus = true
    var onSubmit: () -> Void = {}

    @Environment(SearchReveal.self) private var reveal: SearchReveal?

    var body: some View {
        HStack(spacing: 12) {
            field
                .disabled(isDisabled)
            if offersPaste && isFocused.wrappedValue && text.isEmpty {
                // Apple's own Paste control, so iOS doesn't ask before pasting. Styled as close
                // to Cancel as iOS allows.
                PasteButton(payloadType: String.self) { strings in
                    guard let pasted = strings.first else { return }
                    Task { @MainActor in text = pasted.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
                .labelStyle(.titleOnly)
                // iOS always fills this control and draws its label white; only the fill can be
                // chosen, so it's a warm gray pill.
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .font(.callout)
                .tint(Theme.pasteFill)
                .fixedSize()
                .transition(.opacity.animation(.easeOut(duration: 0.12).delay(0.2)))
            }
            // Stays while there's a search, even after the keyboard is swiped away.
            if isFocused.wrappedValue || !text.isEmpty {
                Button {
                    text = ""
                    isFocused.wrappedValue = false
                } label: {
                    Text("Cancel")
                        .font(.callout)
                        .foregroundStyle(Theme.accent)
                        .fixedSize()
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityHint("Clears the search and closes the keyboard")
                // Fades in only once the field has made room, so it never shows over the field;
                // leaves quickly before the field widens again.
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.12).delay(0.2)),
                    removal: .opacity.animation(.easeOut(duration: 0.08))
                ))
            }
        }
        .animation(.easeOut(duration: 0.2), value: isFocused.wrappedValue || !text.isEmpty)
        .id(Self.scrollID)
        .onChange(of: isFocused.wrappedValue) { _, focused in
            if focused && revealsOnFocus { reveal?.request() }
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            // Disabled, the box loses its fill and keeps only a dashed outline, its words in a light gray.
            TextField(text: $text, prompt: Text(placeholder).foregroundStyle(isDisabled ? Theme.past : Theme.secondary)) {
                Text(placeholder)
            }
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .focused(isFocused)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, text.isEmpty ? 12 : 6)
        .padding(.vertical, text.isEmpty ? 10 : 6)
        .frame(minHeight: 44)
        .background(isDisabled ? Color.clear : Theme.fieldFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if isDisabled {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .accessibilityValue(isDisabled ? "Unavailable while offline" : "")
    }
}

/// A small gray heading over a list in setup, such as "Topics" or "Following".
struct ListHeading: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.secondary)
            .padding(.top, 18)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A gray dash bullet with text, as on the welcome and last pages.
struct DashLine: View {
    var text: Text

    init(_ text: String) {
        self.text = Text(text)
    }

    init(_ text: Text) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("–")
                .foregroundStyle(Theme.secondary)
                .frame(width: DashColumn.width, alignment: .leading)
                .accessibilityHidden(true)
            text
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// What a search in setup or Settings says when the device has no connection.
enum OfflineMessage {
    static func search(inSetup: Bool) -> String {
        inSetup
            ? "You’re offline. Connect to the internet to search, or skip for now."
            : "You’re offline. Connect to the internet to search."
    }

    /// Everything in Podcasts comes from Apple Podcasts, so offline there is nothing to add.
    static func podcasts(inSetup: Bool) -> String {
        inSetup
            ? "You’re offline. Adding podcasts requires a connection, so skip for now and add them later in Settings."
            : "You’re offline. Adding podcasts requires a connection."
    }

    /// News' search still finds sites in the built-in library; only a pasted address needs the web.
    static let newsSearch = "You’re offline. You can still search the sites listed here, but adding a new site by its address requires a connection."
}

/// The gray note shown under a search box while offline, before anything is typed.
struct OfflineNote: View {
    var text: String

    var body: some View {
        // On the pale slate of the bar under the date, as wide as the search box above it.
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.nowTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.top, 8)
    }
}
