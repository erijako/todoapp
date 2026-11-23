import Foundation
import SwiftData
import WidgetKit

/// Shared storage between the app and the widget extension (via an App Group).
enum AppGroup {
    static let identifier = "group.com.erijako.todoapp"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

enum SharedStore {
    static let schema = Schema([TaskItem.self, TaskStep.self])

    static let container: ModelContainer = {
        do {
            let config = ModelConfiguration(schema: schema, groupContainer: .identifier(AppGroup.identifier))
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Fallback for unsigned builds where the App Group is unavailable.
            let config = ModelConfiguration(schema: schema)
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()
}

/// The currently active mode (Personal / Work), shared with the widget.
enum ModeStore {
    static let key = "currentMode"

    static var current: TaskMode {
        get { TaskMode(rawValue: AppGroup.defaults.string(forKey: key) ?? "") ?? .personal }
        set { AppGroup.defaults.set(newValue.rawValue, forKey: key) }
    }
}

/// Deep links into the app.
enum AppLink {
    static let scheme = "todoapp"
    static let focus = URL(string: "todoapp://focus")!
}

extension ModelContext {
    /// Saves and asks the widgets to refresh.
    func saveAndRefresh() {
        try? save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
