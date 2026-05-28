import Foundation
import EventKit
import SwiftData

@MainActor
class CalendarSyncManager {
    static let shared = CalendarSyncManager()
    private let store = EKEventStore()
    
    // 请求日历权限
    func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            do {
                return try await store.requestFullAccessToEvents()
            } catch {
                return false
            }
        } else {
            do {
                return try await store.requestAccess(to: .event)
            } catch {
                return false
            }
        }
    }
    
    // 保存或更新事件，并返回是否成功同步到日历
    func saveEvent(for task: TaskItem) async -> Bool {
        if let newId = await saveEvent(title: task.title, notes: task.content, startDate: task.startTime, endDate: task.plannedCompletionTime, identifier: task.eventIdentifier) {
            task.eventIdentifier = newId
            return true
        }
        return false
    }
    
    // 独立的值传递方法，避免在 AppIntent 后台线程发生跨 Actor 模型传递导致的崩溃
    func saveEvent(title: String, notes: String, startDate: Date, endDate: Date, identifier: String?) async -> String? {
        let granted = await requestAccess()
        guard granted else { return nil }
        
        let event: EKEvent
        if let identifier = identifier, let existingEvent = store.event(withIdentifier: identifier) {
            event = existingEvent
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = store.defaultCalendarForNewEvents
        }
        
        event.title = title
        event.notes = notes.isEmpty ? nil : notes
        event.startDate = startDate
        event.endDate = endDate
        
        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("保存日历事件失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 删除事件
    func deleteEvent(identifier: String?) {
        guard let identifier = identifier else { return }
        guard let event = store.event(withIdentifier: identifier) else { return }
        try? store.remove(event, span: .thisEvent)
    }
}