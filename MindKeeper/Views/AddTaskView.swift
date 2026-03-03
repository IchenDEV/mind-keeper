import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var notes = ""
    @State private var manualPriority: Int = 5
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            inputField("标题") {
                TextField("输入任务内容…", text: $title)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(10)
                    .glassEffect(.clear, in: .rect(cornerRadius: 10))
                    .focused($isTitleFocused)
            }

            inputField("备注") {
                TextField("可选的补充说明…", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .lineLimit(3...5)
                    .padding(10)
                    .glassEffect(.clear, in: .rect(cornerRadius: 10))
            }

            inputField("优先级") {
                Picker("优先级", selection: $manualPriority) {
                    Text("低").tag(3)
                    Text("中").tag(5)
                    Text("高").tag(8)
                    Text("紧急").tag(10)
                }
                .pickerStyle(.segmented)
            }

            Spacer()

            Button(action: submitTask) {
                Text("添加任务")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.tint, in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        }
        .padding(16)
        .onAppear { isTitleFocused = true }
    }

    private func inputField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func submitTask() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let task = TaskItem(
            title: trimmed,
            body: notes.trimmingCharacters(in: .whitespaces),
            source: .manual,
            urgency: manualPriority,
            importance: manualPriority
        )
        task.priority = Double(manualPriority)

        modelContext.insert(task)
        appState.addTask(task)
        do {
            try modelContext.save()
        } catch {
            print("[MindKeeper] Save failed: \(error.localizedDescription)")
        }
        coordinator.triggerReschedule()

        withAnimation(.spring(.smooth(duration: 0.35))) {
            appState.activePanel = .cardStack
        }

        title = ""
        notes = ""
        manualPriority = 5
    }
}
