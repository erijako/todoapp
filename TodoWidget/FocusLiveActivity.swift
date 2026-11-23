import ActivityKit
import SwiftUI
import WidgetKit

/// Lock screen + Dynamic Island countdown while focusing. Makes time visible.
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            FocusLockScreenView(state: context.state, isStale: context.isStale, modeSymbol: context.attributes.modeSymbol)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(AppLink.focus)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Focus", systemImage: "scope")
                        .font(.caption.bold())
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(state: state, isStale: context.isStale)
                        .font(.title3.bold())
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    FocusActions()
                }
            } compactLeading: {
                Image(systemName: "scope")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                CountdownText(state: state, isStale: context.isStale)
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "scope")
                    .foregroundStyle(.tint)
            }
            .widgetURL(AppLink.focus)
            .keylineTint(.accentColor)
        }
    }
}

struct FocusLockScreenView: View {
    let state: FocusActivityAttributes.ContentState
    let isStale: Bool
    let modeSymbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(state.subtitle ?? String(localized: "Focus"))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: modeSymbol)
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)

                Spacer()

                CountdownText(state: state, isStale: isStale)
                    .font(.title2.bold())
                    .frame(maxWidth: 110, alignment: .trailing)
            }

            Text(state.title)
                .font(.headline)
                .lineLimit(2)

            if !isStale {
                ProgressView(
                    timerInterval: state.start...state.end,
                    countsDown: true,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .tint(.accentColor)
            }

            FocusActions()
        }
        .foregroundStyle(.white)
    }
}

/// Live countdown that the system updates every second, no app needed.
struct CountdownText: View {
    let state: FocusActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if isStale || state.end <= .now {
            Text("Time's up")
        } else {
            Text(timerInterval: state.start...state.end, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }
}

struct FocusActions: View {
    var body: some View {
        HStack(spacing: 12) {
            Button(intent: CompleteFocusTaskIntent()) {
                Label("Done", systemImage: "checkmark")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .tint(.accentColor)

            Button(intent: StopFocusIntent()) {
                Label("Stop", systemImage: "stop.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .tint(.gray)
        }
    }
}
