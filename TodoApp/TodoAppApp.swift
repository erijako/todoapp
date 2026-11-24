import SwiftUI
import SwiftData

@main
struct TodoAppApp: App {
    @State private var pro = ProStore()
    @State private var sharing = SharingStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(pro)
                .environment(sharing)
        }
        .modelContainer(SharedStore.container)
    }
}
