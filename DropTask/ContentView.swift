//
//  ContentView.swift
//  DropTask
//
//  Created by Xiangjun Ju on 2026-05-28 17:05.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ServiceManagement

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    
    // 设定下拉列表显示的最多条数，超出此数量才出现滚动条
    private let maxVisibleItems = 5
    @State private var rowHeights: [UUID: CGFloat] = [:]
    
    @State private var isExporting = false
    @State private var exportDocument = TaskExportDocument(text: "")

    // 增加过滤状态变量。默认状态选"未完成"以保持您之前的体验（也可手动选"全部"不过滤）
    @State private var selectedStatusFilter: String = "未完成"
    @State private var selectedCategoryFilter: String = "全部"
    
    // 新增：搜索文本和自启动状态
    @State private var searchText: String = ""
    @State private var isLaunchAtLoginEnabled: Bool = SMAppService.mainApp.status == .enabled

    // 1. 使用 @Query 获取按时间排序的所有任务
    @Query(sort: \TaskItem.plannedCompletionTime, order: .forward) private var allTasks: [TaskItem]

    // 提取当前所有的分类，用于在选择器中展示
    private var availableCategories: [String] {
        let cats = allTasks.map { $0.category }.filter { !$0.isEmpty }
        return ["全部"] + Array(Set(cats)).sorted()
    }

    // 2. 使用计算属性进行过滤，绕开 #Predicate 对 Enum 的局限性
    private var tasks: [TaskItem] {
        allTasks.filter { task in
            // 状态过滤逻辑：全部、未完成、或是具体的某个状态
            let statusMatch = selectedStatusFilter == "全部" ? true :
                             (selectedStatusFilter == "未完成" ? task.status != .completed : task.status.rawValue == selectedStatusFilter)
            
            // 分类过滤逻辑：全部，或者是具体匹配的分类
            let categoryMatch = selectedCategoryFilter == "全部" || task.category == selectedCategoryFilter
            
            // 搜索过滤逻辑：标题或内容包含搜索词
            let searchMatch = searchText.isEmpty || task.title.localizedCaseInsensitiveContains(searchText) || task.content.localizedCaseInsensitiveContains(searchText)
            
            return statusMatch && categoryMatch && searchMatch
        }
    }
    
    // 根据前几条任务的实际高度，动态计算 ScrollView 的高度
    private var scrollHeight: CGFloat {
        let visibleTasks = tasks.prefix(maxVisibleItems)
        var totalHeight: CGFloat = 0
        for task in visibleTasks {
            // 尚未测量时给一个合理的估算高度 70，绝对防止菜单坍缩为 0
            totalHeight += rowHeights[task.taskId] ?? 70 
        }
        return totalHeight + 16 // 加上 VStack 上的 padding(.vertical, 8) 产生的 16 间距
    }

    var body: some View {
        VStack(spacing: 0) {
            // --- 顶部过滤工具栏 ---
            VStack(spacing: 8) {
                HStack {
                    Picker("状态", selection: $selectedStatusFilter) {
                        Text("所有状态").tag("全部")
                        Text("未完成").tag("未完成") 
                        Divider()
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status.rawValue)
                        }
                    }
                    .labelsHidden()
                    
                    Spacer()
                    
                    Picker("分类", selection: $selectedCategoryFilter) {
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat == "全部" ? "所有分类" : cat).tag(cat)
                        }
                    }
                    .labelsHidden()
                }
                
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("搜索任务...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()

            if tasks.isEmpty {
                Text("没有符合条件的任务 🎉")
                    .padding()
                    .foregroundColor(.secondary)
            } else {
                // 使用 ScrollView + VStack 替代 List，让高度能够动态自适应内容
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(tasks) { task in
                            TaskRowView(task: task)
                                .padding(.horizontal, 16) // 补充原本 List 自带的左右边距
                                .contentShape(Rectangle()) // 确保整行区域都可以点击，而不仅是文字部分
                                // CTRL+Click 事件：将任务状态改为已完成 (使用高优先级拦截普通单击)
                                .highPriorityGesture(
                                    TapGesture()
                                        .modifiers(.control)
                                        .onEnded {
                                            task.status = .completed
                                            
                                            Task {
                                                await ReminderSyncManager.shared.saveReminder(for: task)
                                            }
                                        }
                                )
                                // 普通单击事件：打开编辑窗口
                                .onTapGesture(count: 1) {
                                    // 强制将我们的应用激活置前，突破 Xcode 等其他应用的遮挡
                                    NSApplication.shared.activate(ignoringOtherApps: true)
                                    openWindow(id: "edit-task-window", value: task.taskId)
                                }
                            // 测量每一行的实际高度并上报
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(key: RowHeightPreferenceKey.self, value: [task.taskId: geo.size.height])
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(height: scrollHeight) // 明确指定高度，强制撑开 MenuBar 窗口
                .scrollDisabled(tasks.count <= maxVisibleItems) // 如果不超过设定条数，直接禁用滚动
                .onPreferenceChange(RowHeightPreferenceKey.self) { prefs in
                    self.rowHeights = prefs
                }
            }

            Divider()

            HStack {
                Button("新增任务") {
                    // 新增任务时也强制置前
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: "add-task-window")
                }

                Spacer()
                
                Button("导出") {
                    // 唤起保存面板前强制激活应用置前，防止保存窗口被遮挡
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    exportTasks()
                }
                
                Spacer()
                
                // 设置菜单：包含自启动和退出
                Menu {
                    Toggle("开机自启", isOn: Binding(
                        get: { isLaunchAtLoginEnabled },
                        set: { newValue in
                            isLaunchAtLoginEnabled = newValue
                            toggleLaunchAtLogin(enabled: newValue)
                        }
                    ))
                    Divider()
                    Button("退出应用", role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding()
        }
        // 宽度固定，高度不再做全局限制，让内部 ScrollView 根据设定的条数精准撑开
        .frame(width: 350)
        // 实现拖拽创建任务：支持将选中的文本直接拖入应用面板
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    if let text = text {
                        DispatchQueue.main.async {
                            let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !title.isEmpty else { return }
                            let newTask = TaskItem(
                                title: title, content: "", priority: .medium,
                                status: .notStarted, plannedCompletionTime: Date().addingTimeInterval(3600)
                            )
                            modelContext.insert(newTask)
                            Task { await ReminderSyncManager.shared.saveReminder(for: newTask) }
                        }
                    }
                }
            }
            return true
        }
        .onAppear {
            // 每次打开菜单栏弹窗时，注册监听并主动同步一次系统提醒事项的最新状态
            ReminderSyncManager.shared.startObserving(context: modelContext)
            ReminderSyncManager.shared.syncRemindersToTasks(context: modelContext)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: UTType(filenameExtension: "md") ?? .plainText,
            defaultFilename: "DropTask任务导出.md"
        ) { result in
            if case .failure(let error) = result {
                print("导出失败: \(error.localizedDescription)")
            }
        }
    }

    // 导出功能实现
    private func exportTasks() {
        // 1. 以 Markdown 格式导出
        var markdownString = "# DropTask 任务导出\n\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        for task in allTasks {
            let isCompleted = task.status == .completed
            let checkbox = isCompleted ? "- [x]" : "- [ ]"
            
            markdownString += "\(checkbox) **\(task.title)**\n"
            
            if !task.category.isEmpty {
                markdownString += "  - **分类:** \(task.category)\n"
            }
            markdownString += "  - **优先级:** \(task.priority.rawValue)\n"
            markdownString += "  - **状态:** \(task.status.rawValue)\n"
            markdownString += "  - **计划完成:** \(dateFormatter.string(from: task.plannedCompletionTime))\n"
            
            if !task.content.isEmpty {
                let indentedContent = task.content.replacingOccurrences(of: "\n", with: "\n    ")
                markdownString += "  - **备注:**\n    > \(indentedContent)\n"
            }
            markdownString += "\n"
        }
        
        // 2. 通过 SwiftUI 的 fileExporter 唤起系统保存文件面板
        exportDocument = TaskExportDocument(text: markdownString)
        isExporting = true
    }
    
    // 开机自启动开关逻辑
    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            print("开机自启动设置失败: \(error)")
            isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}

struct TaskRowView: View {
    let task: TaskItem

    var body: some View {
        HStack(alignment: .top) { // 采用顶部对齐，防止内容多行时圆点居中显得奇怪
            Circle()
                .fill(statusColor(for: task.status))
                .frame(width: 8, height: 8)
                .padding(.top, 6) // 让圆点与标题的视觉中心对齐
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(task.title)
                        // 使用系统 headline 尺寸，但加上 rounded 圆体设计，并加粗一点
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(priorityColor(for: task.priority)) // 用重要性颜色渲染标题
                    Text(task.plannedCompletionTime, format: .dateTime.year().month().day())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 只有当内容不为空时才显示内容行
                if !task.content.isEmpty {
                    Text(task.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 5) // 为内容上下各空出 5 个 Pixel 的间隔
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text(task.status.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 分类标签直接显示，不再需要外层的 HStack
                if !task.category.isEmpty {
                    Text(task.category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                }
            }
            .padding(.top, 4) // 让状态文字与标题对齐
        }
        .padding(.vertical, 4) // 增加每行的上下留白，让卡片呼吸感更强
    }

    private func statusColor(for status: TaskStatus) -> Color {
        switch status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        }
    }

    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .low: return .primary.opacity(0.3) // 浅透明度，视觉上最弱
        case .medium: return .primary.opacity(0.7) // 中等透明度
        case .high: return .primary // 默认文字颜色，最醒目
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TaskItem.self, inMemory: true)
}

// 用于传递每一行任务高度的 PreferenceKey
struct RowHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

// 用于 SwiftUI fileExporter 的文件文档类型
struct TaskExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            text = string
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
