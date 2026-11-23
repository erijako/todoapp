import SwiftUI

/// No-shame rollover. Unfinished tasks simply stay where they are. On a new day we say
/// hello once, show what came along, and offer to park some of it in Later. Never "overdue".
enum NewDayStore {
    /// The last day the user saw (and dismissed) the new-day card, as "yyyy-MM-dd".
    static let acknowledgedKey = "newDayAcknowledged"
    /// Whether the Later section is expanded.
    static let laterExpandedKey = "laterExpanded"

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// Shown at the top of the list on the first visit of a new day, if tasks came along.
struct NewDayCard: View {
    let carriedOver: Int
    let doneYesterday: Int
    let onKeep: () -> Void
    let onChoose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sun.horizon")
                    .foregroundStyle(Theme.peachInk)
                EyebrowText("New day")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("^[\(carriedOver) thing](inflect: true) came along from before.")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Group {
                    if doneYesterday > 0 {
                        Text("Yesterday you finished \(doneYesterday). That counts.")
                    } else {
                        Text("That's okay. Keep what matters today, park the rest.")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
            }

            HStack(spacing: 10) {
                Button(action: onKeep) {
                    Text("Keep all")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.accent, in: Capsule())
                        .foregroundStyle(Theme.onAccent)
                }
                .buttonStyle(.plain)

                Button(action: onChoose) {
                    Text("Park some")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.segment, in: Capsule())
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 6)
    }
}

/// Pick which carried-over tasks to park in Later.
struct CarryOverSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tasks: [TaskItem]
    let onPark: ([TaskItem]) -> Void

    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(tasks) { task in
                        let isSelected = selected.contains(task.id)
                        Button {
                            if isSelected { selected.remove(task.id) } else { selected.insert(task.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "moon.zzz.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(isSelected ? Theme.accent : Theme.checkStroke)
                                    .frame(width: 28)
                                    .contentTransition(.symbolEffect(.replace))
                                Text(task.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(isSelected ? Theme.inkSoft : Theme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.paper)
                        .listRowSeparatorTint(Theme.separator)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                } header: {
                    SectionLabel("Tap what can wait")
                } footer: {
                    Text("Parked tasks move to Later. They stay out of sight until you bring them back.")
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.fog)
            .navigationTitle(Text("Park some"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onPark(tasks.filter { selected.contains($0.id) })
                    dismiss()
                } label: {
                    Group {
                        if selected.isEmpty {
                            Text("Keep everything")
                        } else {
                            Text("Park \(selected.count) in Later")
                        }
                    }
                    .font(.headline.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.primaryButton, style: .continuous))
                    .foregroundStyle(Theme.onAccent)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.fog.opacity(0.95))
            }
        }
    }
}
