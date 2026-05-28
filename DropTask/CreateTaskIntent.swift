import AppIntents
import SwiftData
import Foundation

struct CreateTaskIntent: AppIntent {
    // Siri 识别和显示的标题
    static var title: LocalizedStringResource = "新建任务"
    static var description = IntentDescription("在 DropTask 中创建一个新的任务")
    static var openAppWhenRun = false

    // Siri 如果没听清标题，会主动反问这句
    @Parameter(title: "任务标题", requestValueDialog: "您想记录什么任务？")
    var taskTitle: String

    @Parameter(title: "任务内容", default: "")
    var content: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 获取全局共享数据库配置
        let container = TaskDatabase.sharedContainer
        
        // AppIntent 在后台运行，必须创建独立的后台数据上下文，避免与 UI 抢占主线程导致死锁
        let context = ModelContext(container)
        
        let newTask = TaskItem(
            title: taskTitle,
            content: content,
            priority: .medium,
            status: .notStarted,
            plannedCompletionTime: Date().addingTimeInterval(3600) // 默认1小时后
        )
        
        // 1. 存入 SwiftData
        context.insert(newTask)
        
        // 使用值传递进行日历同步，避免跨线程传递 SwiftData 模型 (newTask) 导致的崩溃
        let newEventId = await CalendarSyncManager.shared.saveEvent(
            title: newTask.title,
            notes: newTask.content,
            startDate: newTask.startTime,
            endDate: newTask.plannedCompletionTime,
            identifier: newTask.eventIdentifier
        )
        
        do {
            if let id = newEventId { newTask.eventIdentifier = id }
            try context.save()
            if newEventId != nil {
                return .result(dialog: IntentDialog("好的，已为您在 DropTask 中创建：\(taskTitle)"))
            } else {
                return .result(dialog: IntentDialog("好的，已为您在 DropTask 中创建：\(taskTitle)。日历同步暂未完成，稍后请在应用内允许日历权限。"))
            }
        } catch {
            return .result(dialog: IntentDialog("抱歉，保存任务时出错了。"))
        }
    }
}

// 注册捷径，让 Siri 可以通过短语唤醒
struct TaskShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTaskIntent(),
            phrases: [
//                "用 \(.applicationName) 记一下",
//                "用 \(.applicationName) 添加一个任务",
//                "添加一个 \(.applicationName) 任务",
//                "在 \(.applicationName) 中新建任务",
                "Add a task in \(.applicationName)",
                "Create a task in \(.applicationName)",
                "Remind me in \(.applicationName)"
            ],
            shortTitle: "新建任务",
            systemImageName: "checklist"
        )
    }
}
