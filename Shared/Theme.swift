import SwiftUI
import UIKit

/// "Calm & Soft" design tokens. One place for every color, so light and dark mode stay consistent.
/// Mockups: see the design canvas linked in FEATURES.md.
enum Theme {
    // Grounds and surfaces
    static let fog = Color(light: 0xF4F5F8, dark: 0x14161F)          // app background
    static let paper = Color(light: 0xFFFFFF, dark: 0x1E2130)        // cards, rows
    static let focusGround = Color(light: 0xEEF0FA, dark: 0x181B28)  // focus mode background
    static let segment = Color(light: 0xE7E9F0, dark: 0x262A3B)
    static let separator = Color(light: 0xEEF0F4, dark: 0x2A2E40)

    // Text
    static let ink = Color(light: 0x1E2233, dark: 0xECEEF6)
    static let inkSoft = Color(light: 0x5B6178, dark: 0xA3A8BD)

    // Accent (periwinkle) and its companions
    static let accent = Color(light: 0x4F5FCC, dark: 0x9AA5F2)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x141622)
    static let track = Color(light: 0xDDE0F2, dark: 0x2C3150)
    static let currentRow = Color(light: 0xF3F4FC, dark: 0x252A42)
    static let checkStroke = Color(light: 0x878CA0, dark: 0x6A7090)  // 3:1 against paper

    // Thoughts (peach), Personal (sage), pin
    static let peach = Color(light: 0xFCEDE2, dark: 0x3A2C24)
    static let peachInk = Color(light: 0x9A5226, dark: 0xE9A57C)    // 4.5:1 on peach
    static let thoughtInk = Color(light: 0x3A2A20, dark: 0xF3DCCB)
    static let sage = Color(light: 0xE3EFE8, dark: 0x24342D)
    static let pin = Color(light: 0xC07A4F, dark: 0xE0A27A)

    // Live Activity (always on a dark, translucent background)
    enum Live {
        static let background = Color(hex: 0x141622)
        static let accent = Color(hex: 0x9AA5F2)
        static let label = Color(hex: 0xC9CEF5)
        static let onAccent = Color(hex: 0x141622)
    }

    enum Radius {
        // Three shapes only: cards (24), controls (16), and pills (Capsule).
        static let card: CGFloat = 24
        static let control: CGFloat = 16
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

/// Small uppercase label used above content ("UP NEXT", "STEP 2 OF 4").
struct EyebrowText: View {
    let text: Text

    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(verbatim: Text) { text = verbatim }

    var body: some View {
        text
            .font(.caption.weight(.heavy))
            .tracking(1)
            .textCase(.uppercase)
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
            .font(.footnote.weight(.bold))
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
                    .font(.system(size: size * 0.45, weight: .heavy))
                    .foregroundStyle(Theme.onAccent)
            } else {
                Circle().strokeBorder(isCurrent ? Theme.accent : Theme.checkStroke, lineWidth: isCurrent ? 2.4 : 2)
            }
        }
        .frame(width: size, height: size)
        .symbolEffect(.bounce, value: isDone)
    }
}
