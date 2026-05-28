//
//  DropTaskApp.swift
//  DropTask
//
//  Created by Xiangjun Ju on 2026-05-28 17:05.
//

import SwiftUI
import SwiftData
import AppIntents
import Carbon

// 增加通知名以供全局热键触发和应用响应
extension NSNotification.Name {
    static let toggleDropTaskMenu = NSNotification.Name("ToggleDropTaskMenu")
}

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
        
        // 应用启动时主动请求提醒事项权限
        Task {
            _ = await ReminderSyncManager.shared.requestAccess()
        }
        
        // 对于 macOS 配件(Accessory)应用，请在 Launching 尾声进行注册，确保应用已被系统完整识别
        TaskShortcuts.updateAppShortcutParameters()
        
        setupGlobalHotKey()
    }
    
    private var hotKeyRef: EventHotKeyRef?
    
    private func setupGlobalHotKey() {
        // "DRPT" 对应的四字符 OSType 签名 (0x44525054)
        let hotKeyID = EventHotKeyID(signature: OSType(0x44525054), id: 1)
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // 注册系统级键盘事件回调
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            // 接收到热键后，在主线程抛出通知更新 UI
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .toggleDropTaskMenu, object: nil)
            }
            return noErr
        }, 1, &eventType, nil, nil)
        
        // 使用 Control + Option + D 作为快捷键 (不与绝大部分系统快捷键冲突)
        // D 键的 keyCode 为 0x02 (kVK_ANSI_D)
        // 修饰键：Control (controlKey) + Option (optionKey)
        let modifiers = UInt32(controlKey | optionKey)
        let keyCode = UInt32(kVK_ANSI_D)
        
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

@main
struct DropTaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("DropTask", systemImage: "checklist") {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: .toggleDropTaskMenu)) { _ in
                    // 苹果原生 SwiftUI (MenuBarExtra) 目前不支持通过代码直接“展开”下拉窗口。
                    // 快捷键触发时，将应用强制激活至前台，并播放提示音。
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    NSSound.beep() // 播放一声系统提示音以作反馈
                }
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
