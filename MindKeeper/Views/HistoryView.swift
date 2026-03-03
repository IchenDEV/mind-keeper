import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: HistoryTab = .deferred

    enum HistoryTab: String, CaseIterable {
        case deferred, completed, dropped

        var label: String {
            switch self {
            case .deferred:  "延迟"
            case .completed: "已完成"
            case .dropped:   "已丢弃"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.2)
            tabPicker
            taskList
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(.smooth(duration: 0.3))) {
                    appState.activePanel = .cardStack
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text("历史记录")
                .font(.system(size: 13, weight: .medium))

            Spacer()

            Text("\(currentTasks.count)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(HistoryTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func tabButton(_ tab: HistoryTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            HStack(spacing: 4) {
                Text(tab.label)
                    .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                let count = tasksForTab(tab).count
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(badgeColor(for: tab), in: .capsule)
                }
            }
            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                selectedTab == tab
                    ? AnyShapeStyle(.ultraThinMaterial)
                    : AnyShapeStyle(.clear),
                in: .capsule
            )
        }
        .buttonStyle(.plain)
    }

    private func badgeColor(for tab: HistoryTab) -> Color {
        switch tab {
        case .deferred:  .orange
        case .completed: .green
        case .dropped:   .gray
        }
    }

    // MARK: - Task List

    private var currentTasks: [TaskItem] {
        tasksForTab(selectedTab)
    }

    private func tasksForTab(_ tab: HistoryTab) -> [TaskItem] {
        switch tab {
        case .deferred:  appState.deferredTasks
        case .completed: appState.completedTasks
        case .dropped:   appState.droppedTasks
        }
    }

    private var taskList: some View {
        Group {
            if currentTasks.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(currentTasks, id: \.id) { task in
                            historyRow(task)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .clipShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: emptyIcon)
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(.secondary.opacity(0.4))
            Text(emptyText)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyIcon: String {
        switch selectedTab {
        case .deferred:  "clock"
        case .completed: "checkmark.circle"
        case .dropped:   "xmark.circle"
        }
    }

    private var emptyText: String {
        switch selectedTab {
        case .deferred:  "没有延迟中的任务"
        case .completed: "还没有完成的任务"
        case .dropped:   "没有丢弃的任务"
        }
    }

    // MARK: - Row

    private func historyRow(_ task: TaskItem) -> some View {
        HStack(spacing: 10) {
            AppIconView(bundleId: task.appBundleId, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let app = task.appName {
                        Text(app)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(timeLabel(for: task))
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }

            Spacer(minLength: 4)

            rowActions(task)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
    }

    private func timeLabel(for task: TaskItem) -> String {
        let date = task.processedAt ?? task.lastDeferredAt ?? task.createdAt
        return date.relativeDisplay
    }

    @ViewBuilder
    private func rowActions(_ task: TaskItem) -> some View {
        switch selectedTab {
        case .deferred:
            HStack(spacing: 6) {
                smallButton("arrow.uturn.forward", color: .blue) {
                    appState.requeueDeferred(task)
                }
                smallButton("xmark", color: .secondary) {
                    appState.dropDeferred(task)
                }
            }
        case .completed:
            smallButton("arrow.uturn.left", color: .blue) {
                appState.requeueFromHistory(task)
            }
        case .dropped:
            smallButton("arrow.uturn.left", color: .blue) {
                appState.requeueFromHistory(task)
            }
        }
    }

    private func smallButton(_ icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
