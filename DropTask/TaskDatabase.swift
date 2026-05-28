import SwiftData
import Foundation

enum TaskDatabase {
    static let schema = Schema([TaskItem.self])

    static let sharedContainer: ModelContainer = {
        let modelConfiguration = ModelConfiguration(
            "DropTaskTasks",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Unable to create DropTask model container: \(error)")
        }
    }()
}