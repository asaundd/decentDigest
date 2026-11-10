import SwiftUI
import UIKit

/// One setup step: ‹ Back and "Step N of 4" at the top, a Georgia title over a gray intro, the
/// step's choices, an optional small gray note, then Continue (dimmed until something is chosen)
/// with Skip for now under it.
struct OnboardingStep<Content: View>: View {
    var number: Int
    var title: String
    var intro: String
    var note: String?
    var canContinue: Bool
    var back: () -> Void
    var skip: () -> Void
    var next: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
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
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 4) {
                PrimaryButton(title: "Continue", isEnabled: canContinue, action: next)
                Button(action: skip) {
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
        .onboardingPage()
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
    /// A gray dash before the name, for items listed under a heading or a topic.
    var dashed = false
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
        .padding(.vertical, 6)
    }

    private var choiceText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .fontWeight(emphasized ? .semibold : .regular)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

/// A filled search box, so it's clear it can be typed in. An ✕ clears it while it holds text, and
/// Done above the keyboard puts the keyboard away.
struct SearchBox: View {
    var placeholder: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var keyboard: UIKeyboardType = .default
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isFocused.wrappedValue = false }
                    .fontWeight(.semibold)
                    .tint(Theme.accent)
            }
        }
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
