import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // 查询所有任务，用来提取现有的全部分类
    @Query private var allTasks: [TaskItem]

    // 如果传入了 id，说明是编辑模式；如果为 nil，说明是新增模式
    var editingTaskId: UUID?

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var category: String = ""
    @State private var priority: TaskPriority = .medium
    @State private var status: TaskStatus = .notStarted
    @State private var plannedCompletionTime: Date = Date().addingTimeInterval(3600)
    
    // 标记数据是否已加载，防止重复覆盖用户的输入
    @State private var hasLoaded: Bool = false

    private var availableCategories: [String] {
        let cats = allTasks.map { $0.category }.filter { !$0.isEmpty }
        return Array(Set(cats)).sorted() // 去重并排序
    }

    var body: some View {
        VStack {
            Text(editingTaskId == nil ? String(localized: "新增任务") : String(localized: "编辑任务"))
                .font(.headline)
                .padding(.bottom)

            // 彻底抛弃 Form，使用纯 VStack 自定义紧凑布局
            // 增加 alignment: .leading，防止宽度不够时组件居中导致错位
            VStack(alignment: .leading, spacing: 12) {
                TextField("任务标题", text: $title)
                    .textFieldStyle(.roundedBorder)
                
                TextField("添加备注 (可选)", text: $content, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)
                
                Divider().padding(.vertical, 4)
                
                HStack {
                    Text("分类").foregroundColor(.secondary).frame(width: 35, alignment: .leading)
                    TextField("输入或选择", text: $category)
                        .textFieldStyle(.roundedBorder)
                    if !availableCategories.isEmpty {
                        Menu {
                            ForEach(availableCategories, id: \.self) { cat in
                                Button(cat) { category = cat }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }

                HStack {
                    Text("重要").foregroundColor(.secondary).frame(width: 35, alignment: .leading)
                    Picker("", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                        Text(priority.localizedName).tag(priority)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented) // 分段选择器更加扁平紧凑
                    Spacer() // 添加 Spacer 让 HStack 占满全宽，保证左侧标签完美对齐
                }
                
                HStack {
                    Text("状态").foregroundColor(.secondary).frame(width: 35, alignment: .leading)
                    Picker("", selection: $status) {
                        ForEach(TaskStatus.allCases, id: \.self) { s in
                        Text(s.localizedName).tag(s)
                        }
                    }
                    .labelsHidden()
                    Spacer()
                }
                
                HStack {
                    Text("时间").foregroundColor(.secondary).frame(width: 35, alignment: .leading)
                    DatePicker("", selection: $plannedCompletionTime, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                    Spacer()
                }
            }

            HStack {
                if editingTaskId != nil {
                    Button("删除任务", role: .destructive) {
                        deleteTask()
                    }
                } else {
                    Button("取消") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }

                Spacer()
                
                Button("保存") {
                    saveTask()
                    dismiss()
                }
                .disabled(title.isEmpty)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 280) // 极致紧凑宽度，彻底告别大量留白
        .onAppear {
            loadExistingTask()
        }
        .onChange(of: allTasks) { _, _ in
            // 确保 SwiftData 数据加载完成后渲染到表单
            loadExistingTask()
        }
    }

    private func loadExistingTask() {
        guard !hasLoaded, let editingTaskId = editingTaskId else { return }
        if let task = allTasks.first(where: { $0.taskId == editingTaskId }) {
            self.title = task.title
            self.content = task.content
            self.category = task.category
            self.priority = task.priority
            self.status = task.status
            self.plannedCompletionTime = task.plannedCompletionTime
            self.hasLoaded = true
        }
    }

    private func saveTask() {
        guard !title.isEmpty else { return }
        
        if let editingTaskId = editingTaskId, let task = allTasks.first(where: { $0.taskId == editingTaskId }) {
            // 更新已有任务
            task.title = title
            task.content = content
            task.category = category
            task.priority = priority
            task.status = status
            task.plannedCompletionTime = plannedCompletionTime
            
            // 更新系统提醒事项
            Task {
                await ReminderSyncManager.shared.saveReminder(for: task)
            }
        } else {
            // 创建新任务
            let newTask = TaskItem(
                title: title,
                content: content,
                category: category,
                priority: priority,
                status: status,
                plannedCompletionTime: plannedCompletionTime
            )
            modelContext.insert(newTask)
            
            // 同步到系统提醒事项
            Task {
                await ReminderSyncManager.shared.saveReminder(for: newTask)
            }
        }
    }
    
    private func deleteTask() {
        if let editingTaskId = editingTaskId, let task = allTasks.first(where: { $0.taskId == editingTaskId }) {
            // 从系统提醒事项中删除
            ReminderSyncManager.shared.deleteReminder(identifier: task.eventIdentifier)
            modelContext.delete(task)
        }
        dismiss()
    }
}
