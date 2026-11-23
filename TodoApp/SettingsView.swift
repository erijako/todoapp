import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var store

    @State private var showPaywall = false
    @State private var showManage = false
    @State private var isRestoring = false
    @State private var message: String?

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if store.isPro {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Theme.peachInk)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pro is active")
                                    .font(.body.weight(.bold))
                                if store.activeProductID == ProProduct.lifetime {
                                    Text("Lifetime. Thank you!")
                                        .font(.footnote)
                                        .foregroundStyle(Theme.inkSoft)
                                } else {
                                    Text("Thank you for supporting the app.")
                                        .font(.footnote)
                                        .foregroundStyle(Theme.inkSoft)
                                }
                            }
                        }
                        .listRowBackground(Theme.paper)

                        if store.activeProductID != ProProduct.lifetime {
                            Button("Manage subscription") { showManage = true }
                                .listRowBackground(Theme.paper)
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "hourglass")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Try Pro")
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(Theme.ink)
                                    Text("Focus timer on your lock screen")
                                        .font(.footnote)
                                        .foregroundStyle(Theme.inkSoft)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .listRowBackground(Theme.paper)
                    }

                    Button {
                        restore()
                    } label: {
                        HStack {
                            Text("Restore purchases")
                            if isRestoring {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRestoring)
                    .listRowBackground(Theme.paper)
                } header: {
                    SectionLabel("Pro")
                }

                Section {
                    Link("Terms of Use", destination: Legal.terms)
                        .listRowBackground(Theme.paper)
                    Link("Privacy Policy", destination: Legal.privacy)
                        .listRowBackground(Theme.paper)
                    LabeledContent("Version", value: version)
                        .listRowBackground(Theme.paper)
                } header: {
                    SectionLabel("About")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.fog)
            .foregroundStyle(Theme.ink)
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.heavy)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environment(store)
                    .tint(Theme.accent)
                    .fontDesign(.rounded)
            }
            .manageSubscriptionsSheet(isPresented: $showManage)
            .alert(Text("Restore purchases"), isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            defer { isRestoring = false }
            do {
                try await store.restore()
                message = store.isPro
                    ? String(localized: "Pro is back. Welcome!")
                    : String(localized: "We couldn't find an earlier Pro purchase for this Apple ID.")
            } catch {
                message = error.localizedDescription
            }
        }
    }
}
