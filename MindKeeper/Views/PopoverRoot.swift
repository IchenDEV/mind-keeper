import SwiftUI

struct PopoverRoot: View {
    @Environment(AppState.self) private var appState
    @Namespace private var panelTransition

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                headerBar
                Divider().opacity(0.2)
                contentArea
                Divider().opacity(0.2)
                bottomToolbar
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { handleKey(.up) }
        .onKeyPress(.leftArrow) { handleKey(.left) }
        .onKeyPress(.rightArrow) { handleKey(.right) }
        .onKeyPress(.return) { handleKey(.up) }
        .onKeyPress(.delete) { handleKey(.right) }
    }

    private func handleKey(_ direction: SwipeDirection) -> KeyPress.Result {
        guard appState.activePanel == .cardStack,
              let task = appState.pendingTasks.first else {
            return .ignored
        }
        switch direction {
        case .up: appState.markCompleted(task)
        case .left: appState.markDeferred(task)
        case .right: appState.markDropped(task)
        case .none: break
        }
        return .handled
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Mind Keeper")
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitleText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            headerAction
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var headerAction: some View {
        switch appState.activePanel {
        case .cardStack:
            headerButton(icon: "plus") {
                withAnimation(.spring(.smooth(duration: 0.35))) {
                    appState.activePanel = .addTask
                }
            }
        case .addTask:
            headerButton(icon: "xmark") {
                withAnimation(.spring(.smooth(duration: 0.35))) {
                    appState.activePanel = .cardStack
                }
            }
        default:
            EmptyView()
        }
    }

    private func headerButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    private var contentArea: some View {
        Group {
            switch appState.activePanel {
            case .cardStack:  CardStackView()
            case .addTask:    AddTaskView()
            case .cleanup:    CleanupView()
            case .history:    HistoryView()
            case .settings:   SettingsView()
            case .onboarding: OnboardingView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            toolbarButton(icon: "clock.arrow.circlepath", badge: appState.historyBadgeCount) {
                withAnimation(.spring(.smooth(duration: 0.3))) {
                    appState.activePanel = .history
                }
            }

            Spacer()

            toolbarButton(icon: "archivebox", badge: appState.expiredBadgeCount) {
                withAnimation(.spring(.smooth(duration: 0.3))) {
                    appState.activePanel = .cleanup
                }
            }

            Spacer()

            Text("\(appState.pendingTasks.count)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)

            Spacer()

            toolbarButton(icon: "gearshape", badge: 0) {
                withAnimation(.spring(.smooth(duration: 0.3))) {
                    appState.activePanel = .settings
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func toolbarButton(icon: String, badge: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)

                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(2.5)
                        .background(.red, in: Circle())
                        .offset(x: 7, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var subtitleText: String {
        let count = appState.badgeCount
        return count > 0 ? "\(count) 项待处理" : "一切就绪"
    }
}
