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

/// One setup step: ‹ Back and "Step N of 4" at the top, a Georgia title over a gray intro, the
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
        .alert(skipQuestion?.title ?? "", isPresented: $asksToSkip) {
            Button(skipQuestion?.confirm ?? "Skip", role: skipQuestion?.destructive == false ? nil : .destructive) {
                skipQuestion?.undo()
                skip()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(skipQuestion?.message ?? "")
        }
        .onboardingPage()
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
            .background(Theme.page)
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
                .foregroundStyle(isEnabled ? Theme.page : Theme.buttonDimmedText)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    isEnabled ? Theme.accent : Theme.buttonDimmedFill,
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
/// (Allow, Follow, ✓ Following, Choose…).
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

/// Follow (slate), which becomes Unfollow (gray, faint underline): the link says what a tap does.
struct FollowLink: View {
    var title: String
    var isFollowing: Bool
    var toggle: () -> Void

    var body: some View {
        if isFollowing {
            QuietLink("Unfollow", action: toggle)
                .accessibilityLabel("Unfollow \(title)")
        } else {
            TextLink("Follow", action: toggle)
                .accessibilityLabel("Follow \(title)")
        }
    }
}

/// A link that undoes a choice (Unfollow, Hide): gray, with a faint underline a little below the text.
struct QuietLink: View {
    var title: String
    var action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.actionFont)
                .foregroundStyle(Theme.secondary)
                .fixedSize()
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Theme.faintUnderline)
                        .frame(height: 1)
                        .offset(y: 3)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
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
    var onSubmit: () -> Void = {}

    @Environment(SearchReveal.self) private var reveal: SearchReveal?

    var body: some View {
        HStack(spacing: 12) {
            field
            if offersPaste && isFocused.wrappedValue && text.isEmpty {
                // Apple's own Paste control, so iOS doesn't ask before pasting. Styled as close
                // to Cancel as iOS allows.
                PasteButton(payloadType: String.self) { strings in
                    guard let pasted = strings.first else { return }
                    Task { @MainActor in text = pasted.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
                .labelStyle(.titleOnly)
                // iOS always fills this control: a light warm pill with dark gray text.
                // (iOS checks the label stays readable.)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .font(.callout)
                .tint(Theme.pasteFill)
                .foregroundStyle(Theme.itemInk)
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
            if focused { reveal?.request() }
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
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
        .background(Theme.fieldFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// A small gray heading over a list in setup, such as "Topics" or "Suggested".
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
