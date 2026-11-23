import SwiftUI
import SwiftData

@main
struct TodoAppApp: App {
    @State private var pro = ProStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(pro)
        }
        .modelContainer(SharedStore.container)
    }
}
