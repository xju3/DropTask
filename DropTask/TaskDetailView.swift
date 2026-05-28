import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // 使用 @Bindable 可以让视图直接双向绑定到 task 对象的属性
    @Bindable var task: TaskItem

    // 同样查询所有任务用来提取现有分类
    @Query private var allTasks: [TaskItem]
    
    private var availableCategories: [String] {
        let cats = allTasks.map { $0.category }.filter { !$0.isEmpty }
        return Array(Set(cats)).sorted()
    }

    var body: some View {
        VStack {
            Text("编辑任务")
                .font(.title2)
                .padding(.bottom)

            Form {
                TextField("标题", text: $task.title)
                
                TextField("内容", text: $task.content, axis: .vertical)
                    .lineLimit(3...)

                HStack {
                    TextField("分类", text: $task.category)
                    
                    if !availableCategories.isEmpty {
                        Menu {
                            ForEach(availableCategories, id: \.self) { cat in
                                Button(cat) { task.category = cat }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }

                Picker("重要性", selection: $task.priority) {
                    ForEach(TaskPriority.allCases, id: \.self) { p in
                        Text(p.localizedName).tag(p)
                    }
                }
                
                Picker("状态", selection: $task.status) {
                    ForEach(TaskStatus.allCases, id: \.self) { s in
                        Text(s.localizedName).tag(s)
                    }
                }

                DatePicker(
                    "计划完成时间",
                    selection: $task.plannedCompletionTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            HStack {
                // role: .destructive 会让按钮在 macOS 上显示为红色
                Button("删除任务", role: .destructive) {
                    deleteTask()
                }

                Spacer()

                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 400)
    }

    private func deleteTask() {
        modelContext.delete(task)
        dismiss() // 删除后自动关闭窗口
    }
}