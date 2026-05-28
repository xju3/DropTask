import Foundation
import EventKit
import SwiftData

@MainActor
class ReminderSyncManager {
    static let shared = ReminderSyncManager()
    private let store = EKEventStore()
    private var observer: Any?
    
    // 请求提醒事项权限
    func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            do {
                return try await store.requestFullAccessToReminders()
            } catch {
                return false
            }
        } else {
            do {
                return try await store.requestAccess(to: .reminder)
            } catch {
                return false
            }
        }
    }
    
    // 保存或更新提醒事项，并返回是否成功同步
    func saveReminder(for task: TaskItem) async -> Bool {
        if let newId = await saveReminder(title: task.title, notes: task.content, dueDate: task.plannedCompletionTime, priority: task.priority, status: task.status, identifier: task.eventIdentifier) {
            task.eventIdentifier = newId
            return true
        }
        return false
    }
    
    // 独立的值传递方法，避免跨 Actor 模型传递导致的崩溃
    func saveReminder(title: String, notes: String, dueDate: Date, priority: TaskPriority, status: TaskStatus, identifier: String?) async -> String? {
        let granted = await requestAccess()
        guard granted else { return nil }
        
        let reminder: EKReminder
        if let identifier = identifier, let existingReminder = store.calendarItem(withIdentifier: identifier) as? EKReminder {
            reminder = existingReminder
        } else {
            reminder = EKReminder(eventStore: store)
            guard let defaultCalendar = store.defaultCalendarForNewReminders() else {
                return nil
            }
            reminder.calendar = defaultCalendar
        }
        
        reminder.title = title
        reminder.notes = notes.isEmpty ? nil : notes
        
        // 设置到期时间
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        reminder.dueDateComponents = components
        
        // 同步完成状态
        reminder.isCompleted = (status == .completed)
        
        // 同步优先级 (1-4:高, 5:中, 6-9:低)
        switch priority {
        case .high: reminder.priority = 1
        case .medium: reminder.priority = 5
        case .low: reminder.priority = 9
        }
        
        do {
            try store.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            print("保存提醒事项失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 删除提醒事项
    func deleteReminder(identifier: String?) {
        guard let identifier = identifier else { return }
        guard let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        try? store.remove(reminder, commit: true)
    }
    
    // --- 双向同步核心逻辑 ---
    
    // 开启监听提醒事项的后台变化
    func startObserving(context: ModelContext) {
        // 确保不重复添加监听器
        if observer == nil {
            // queue 传 nil 代表在后台接收系统通知
            observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: nil) { [weak self] _ in
                guard let self else { return }
                // 开启主线程任务，避免捕获不安全的 context
                Task { @MainActor [self] in
                    let mainContext = TaskDatabase.sharedContainer.mainContext
                    self.syncRemindersToTasks(context: mainContext)
                }
            }
        }
    }
    
    // 将系统提醒事项的状态反向同步回 SwiftData 任务
    func syncRemindersToTasks(context: ModelContext) {
        let descriptor = FetchDescriptor<TaskItem>()
        guard let tasks = try? context.fetch(descriptor) else { return }
        
        var hasChanges = false
        for task in tasks {
            guard let identifier = task.eventIdentifier else { continue }
            
            if let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder {
                let isCompletedInReminder = reminder.isCompleted
                let isCompletedInApp = (task.status == .completed)
                
                // 如果状态不一致，以系统提醒事项的完成状态为准进行更新
                if isCompletedInReminder != isCompletedInApp {
                    task.status = isCompletedInReminder ? .completed : .notStarted
                    hasChanges = true
                }
            }
        }
        if hasChanges { try? context.save() }
    }
}
