import SwiftUI

struct CleanupView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    private var groupedTasks: [(String, [TaskItem])] {
        let sorted = appState.expiredTasks.sorted { $0.createdAt > $1.createdAt }
        let grouped = Dictionary(grouping: sorted) { task in
            task.createdAt.sectionLabel
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if appState.expiredTasks.isEmpty {
                emptyCleanup
            } else {
                taskList
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                withAnimation(.spring(.smooth(duration: 0.3))) {
                    appState.activePanel = .cardStack
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)

            Text("过期清理")
                .font(.subheadline.weight(.medium))

            Spacer()

            if !appState.expiredTasks.isEmpty {
                Menu {
                    Button("全部恢复") { restoreAll() }
                    Button("全部清理", role: .destructive) { dropAll() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(groupedTasks, id: \.0) { section, tasks in
                    Section {
                        ForEach(tasks, id: \.id) { task in
                            CleanupRow(
                                task: task,
                                onRestore: { restore(task) },
                                onDrop: { drop(task) }
                            )
                        }
                    } header: {
                        Text(section)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var emptyCleanup: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("没有过期任务")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func restore(_ task: TaskItem) {
        withAnimation(.spring(.smooth(duration: 0.3))) {
            task.status = .pending
            appState.expiredTasks.removeAll { $0.id == task.id }
            appState.addTask(task)
        }
    }

    private func drop(_ task: TaskItem) {
        withAnimation(.spring(.smooth(duration: 0.3))) {
            task.status = .archived
            task.processedAt = Date()
            appState.expiredTasks.removeAll { $0.id == task.id }
        }
    }

    private func restoreAll() {
        withAnimation(.spring(.smooth(duration: 0.3))) {
            for task in appState.expiredTasks {
                task.status = .pending
                appState.addTask(task)
            }
            appState.expiredTasks.removeAll()
        }
    }

    private func dropAll() {
        withAnimation(.spring(.smooth(duration: 0.3))) {
            for task in appState.expiredTasks {
                task.status = .archived
                task.processedAt = Date()
            }
            appState.expiredTasks.removeAll()
        }
    }
}

// MARK: - Cleanup Row

private struct CleanupRow: View {
    let task: TaskItem
    let onRestore: () -> Void
    let onDrop: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(task.createdAt.relativeDisplay)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button(action: onRestore) {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            Button(action: onDrop) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.clear, in: .rect(cornerRadius: 10))
    }
}

// MARK: - Date Section Helper

private extension Date {
    var sectionLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "今天" }
        if calendar.isDateInYesterday(self) { return "昨天" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: self)
    }
}
