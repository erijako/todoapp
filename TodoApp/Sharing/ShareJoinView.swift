import CloudKit
import SwiftUI

/// S2: someone tapped an invite link. Shown before accepting, so they choose to join.
struct ShareJoinView: View {
    @Environment(SharingStore.self) private var sharing
    @Environment(\.dismiss) private var dismiss

    let metadata: CKShare.Metadata
    /// Called after joining, so the caller can open the shared space.
    let onJoined: () -> Void

    @State private var myName = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var inviter: String {
        metadata.ownerIdentity.nameComponents.map { $0.formatted(.name(style: .short)) }
            ?? String(localized: "Someone")
    }

    private var spaceName: String {
        metadata.share[CKShare.SystemFieldKey.title] as? String ?? String(localized: "Home")
    }

    /// Already in another iCloud space: one space per person.
    private var blockedBy: String? {
        guard sharing.isCloud, let space = sharing.space,
              sharing.cacheZoneName != metadata.share.recordID.zoneID.zoneName else { return nil }
        return space.name
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 14) {
                    MemberAvatar(member: SpaceMember(id: "", displayName: inviter, colorIndex: 0), size: 88)
                        .overlay(alignment: .bottomTrailing) {
                            Circle()
                                .fill(Theme.paper)
                                .frame(width: 34, height: 34)
                                .overlay(Image(systemName: "heart.fill").foregroundStyle(Theme.accent))
                                .offset(x: 4, y: 4)
                                .accessibilityHidden(true)
                        }
                    EyebrowText("You're invited")
                    Text("\(inviter) wants you in \(spaceName)")
                        .font(.largeTitle.weight(.heavy))
                        .multilineTextAlignment(.center)
                    Text("So you can toss each other the odd gentle reminder. Milk, bins, calling grandma.")
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }

                if let blockedBy {
                    Text("You're already in \(blockedBy). Leave it first to join this one.")
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                } else {
                    LabeledField(label: "They'll see you as", text: $myName, prompt: "Your first name")
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.control))

                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "lock")
                            .foregroundStyle(Theme.accent)
                            .accessibilityHidden(true)
                        Text("They can't see your lists. Only the reminders you swap show up here.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if blockedBy == nil {
                    Button(action: join) {
                        ZStack {
                            if isWorking {
                                ProgressView().tint(Theme.onAccent)
                            } else {
                                Text("Join \(spaceName)")
                            }
                        }
                        .font(.body.weight(.heavy))
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.onAccent)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .disabled(myName.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
                    .opacity(myName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
                Button(blockedBy == nil ? "Not now" : "OK") { dismiss() }
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .disabled(isWorking)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .background(Theme.fog)
        }
        .background(Theme.fog)
        .foregroundStyle(Theme.ink)
        .alert(Text("Not just yet"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func join() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await sharing.join(metadata, myName: myName)
                dismiss()
                onJoined()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Shows the join screen when an invite link arrives (see `SceneDelegate`).
struct ShareInviteCover: ViewModifier {
    @Environment(SharingStore.self) private var sharing
    let onJoined: () -> Void

    func body(content: Content) -> some View {
        let inbox = ShareInbox.shared
        // Read here so SwiftUI notices when a link arrives.
        let metadata = inbox.pending
        content.fullScreenCover(isPresented: Binding(
            get: { metadata != nil },
            set: { if !$0 { inbox.pending = nil } }
        )) {
            if let metadata {
                ShareJoinView(metadata: metadata, onJoined: onJoined)
                    .environment(sharing)
                    .tint(Theme.accent)
                    .fontDesign(.rounded)
            }
        }
    }
}
