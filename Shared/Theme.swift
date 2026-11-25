import SwiftUI
import UIKit

/// Style D "System" design tokens: looks as if it shipped with iOS, next to Reminders.
/// One place for every color, so light and dark mode stay consistent.
/// Mockups: the "D · System" rows on the design canvas (see CLAUDE.md).
enum Theme {
    // Grounds and surfaces (iOS grouped style: grey ground, white cards; black + dark grey at night)
    static let fog = Color(light: 0xF2F2F7, dark: 0x000000)          // app background
    static let paper = Color(light: 0xFFFFFF, dark: 0x1C1C1E)        // cards, rows
    static let focusGround = Color(light: 0xFFFFFF, dark: 0x000000)  // focus mode background
    static let segment = Color(light: 0xE3E3E8, dark: 0x2C2C2E)      // pills on paper, chips
    static let separator = Color(light: 0xC6C6C8, dark: 0x38383A)

    // Text
    static let ink = Color(light: 0x000000, dark: 0xFFFFFF)
    static let inkSoft = Color(light: 0x6C6C70, dark: 0xAEAEB2)      // 4.5:1 on fog and paper

    // Tint (indigo, the one accent) and its companions
    static let accent = Color(light: 0x5856D6, dark: 0x8A88FF)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x0B0B1A)     // 4.5:1 on accent
    static let track = Color(light: 0xE5E5EA, dark: 0x2C2C2E)
    static let currentRow = Color(light: 0xEEEEFB, dark: 0x24243A)
    static let checkStroke = Color(light: 0x8E8E93, dark: 0x8E8E93)  // 3:1 against paper

    // Thoughts (peach), Personal (sage), pin
    static let peach = Color(light: 0xFCEDE2, dark: 0x3A2C24)
    static let peachInk = Color(light: 0x9A5226, dark: 0xE9A57C)    // 4.5:1 on peach
    static let thoughtInk = Color(light: 0x3A2A20, dark: 0xF3DCCB)
    static let sage = Color(light: 0xE3EFE8, dark: 0x24342D)
    static let pin = Color(light: 0xC07A4F, dark: 0xE0A27A)

    // Live Activity (always on a dark, translucent background)
    enum Live {
        static let background = Color(hex: 0x1C1C1E)
        static let accent = Color(hex: 0xA9A7FF)
        static let label = Color(hex: 0xC7C7CC)
        static let onAccent = Color(hex: 0x0B0B1A)
        /// Indigo wallpaper used behind lock screen previews (onboarding).
        static let wallpaper = [Color(hex: 0x6E6BD8), Color(hex: 0x2A2966)]
    }

    // Shared-space avatars: soft fill + readable initial (4.5:1), assigned in join order.
    enum Avatar {
        struct Pair {
            let fill: Color
            let ink: Color
        }

        static let palette: [Pair] = [
            Pair(fill: Color(light: 0xFCEDE2, dark: 0x3A2C24), ink: Color(light: 0x9A5226, dark: 0xE9A57C)), // peach
            Pair(fill: Color(light: 0xDDEFE8, dark: 0x203A31), ink: Color(light: 0x24594A, dark: 0x9FD8C2)), // green
            Pair(fill: Color(light: 0xE3E6FA, dark: 0x262B4D), ink: Color(light: 0x2F3A8F, dark: 0xB9C1F7)), // indigo
            Pair(fill: Color(light: 0xEFE6FA, dark: 0x31264A), ink: Color(light: 0x5A3E9A, dark: 0xCDB8F2)), // lilac
        ]

        static func pair(_ index: Int) -> Pair {
            palette[((index % palette.count) + palette.count) % palette.count]
        }
    }

    /// Positive, calm "they've got it" green (text on paper, 4.5:1).
    static let gotIt = Color(light: 0x24594A, dark: 0x9FD8C2)
    /// The little heart next to "added a reminder".
    static let heart = Color(light: 0xE09068, dark: 0xE9A57C)

    enum Radius {
        // Three shapes only: cards (22), controls (14), and pills/circles (Capsule, Circle).
        static let card: CGFloat = 22
        static let control: CGFloat = 14
        static let row: CGFloat = control
        static let primaryButton: CGFloat = control
        static let button: CGFloat = control
        static let field: CGFloat = control
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A color that adapts to light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// Small section label above content ("Up next", "Step 2 of 4"), iOS section-header style.
struct EyebrowText: View {
    let text: Text

    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(verbatim: Text) { text = verbatim }

    var body: some View {
        text
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.inkSoft)
    }
}

/// Section header in lists ("Tasks", "Thoughts").
struct SectionLabel: View {
    let text: Text

    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(verbatim: Text) { text = verbatim }

    var body: some View {
        text
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.inkSoft)
            .textCase(nil)
    }
}

/// The round check button used for tasks and steps.
struct CheckCircle: View {
    let isDone: Bool
    var isCurrent: Bool = false
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            if isDone {
                Circle().fill(Theme.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
            } else {
                Circle().strokeBorder(isCurrent ? Theme.accent : Theme.checkStroke, lineWidth: isCurrent ? 1.8 : 1.5)
            }
        }
        .frame(width: size, height: size)
        .symbolEffect(.bounce, value: isDone)
    }
}

/// Floating "Liquid Glass" capsule on iOS 26, a thin material before that.
struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.separator.opacity(0.4), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        }
    }
}

extension View {
    /// Floating glass button or bar (Style D).
    func glassCapsule() -> some View { modifier(GlassCapsule()) }
}
