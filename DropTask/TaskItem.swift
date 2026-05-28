import Foundation
import SwiftData

@Model
final class TaskItem {
    var taskId: UUID
    var title: String
    var content: String
    var category: String
    var priority: TaskPriority
    var status: TaskStatus
    var startTime: Date // 关联日历事件开始时间
    var plannedCompletionTime: Date
    var eventIdentifier: String? // 用于关联系统日历事件
    
    init(
        taskId: UUID = UUID(),
        title: String,
        content: String = "",
        category: String = "",
        priority: TaskPriority = .medium,
        status: TaskStatus = .notStarted,
        startTime: Date = Date(),
        plannedCompletionTime: Date = Date(),
        eventIdentifier: String? = nil
    ) {
        self.taskId = taskId
        self.title = title
        self.content = content
        self.category = category
        self.priority = priority
        self.status = status
        self.startTime = startTime
        self.plannedCompletionTime = plannedCompletionTime
        self.eventIdentifier = eventIdentifier
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case low = "低"
    case medium = "中"
    case high = "高"
}

enum TaskStatus: String, Codable, CaseIterable {
    case notStarted = "未开始"
    case inProgress = "进行中"
    case completed = "已完成"
}