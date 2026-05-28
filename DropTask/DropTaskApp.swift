//
//  DropTaskApp.swift
//  DropTask
//
//  Created by Xiangjun Ju on 2026-05-28 17:05.
//

import SwiftUI
import SwiftData
import AppIntents

// 用于在应用刚启动时直接干掉多余弹出的窗口
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 【核心修复】将应用设为“配件”模式：只显示在菜单栏，不在 Dock 栏显示，且不弹出默认的主窗口
        NSApp.setActivationPolicy(.accessory)
        
        // 菜单栏下拉弹窗本质上是无标题栏的特殊窗口。
        // 普通的 WindowGroup 窗口带有标题栏 (.titled)。我们通过这个特征来精准关闭主窗口，绝不误杀菜单栏弹窗。
        for window in NSApplication.shared.windows {
            if window.styleMask.contains(.titled) {
                window.close()
            }
        }
        
        // 应用启动时主动请求日历权限
        Task {
            _ = await CalendarSyncManager.shared.requestAccess()
        }
        
        // 对于 macOS 配件(Accessory)应用，请在 Launching 尾声进行注册，确保应用已被系统完整识别
        TaskShortcuts.updateAppShortcutParameters()
    }
}

@main
struct DropTaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("DropTask", systemImage: "checklist") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
        .modelContainer(TaskDatabase.sharedContainer)
        
        // 独立的“新增任务”窗口，默认不在启动时显示
        WindowGroup(id: "add-task-window") {
            TaskEditorView(editingTaskId: nil)
        }
        .modelContainer(TaskDatabase.sharedContainer)
        
        // 独立的“编辑任务”窗口，接收任务的 UUID 作为参数
        WindowGroup(id: "edit-task-window", for: UUID.self) { $taskId in
            TaskEditorView(editingTaskId: taskId)
        }
        .modelContainer(TaskDatabase.sharedContainer)
    }
}
