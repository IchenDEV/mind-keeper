import SwiftUI
import SwiftData

@main
struct MindKeeperApp: App {
    private let appState = AppState()
    private let coordinator: AppCoordinator
    private let modelContainer: ModelContainer

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: TaskItem.self, UserMemory.self)
        } catch {
            print("[MindKeeper] Fatal: ModelContainer init failed: \(error)")
            container = try! ModelContainer(
                for: TaskItem.self, UserMemory.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        self.modelContainer = container
        self.coordinator = AppCoordinator(appState: appState)
        coordinator.start(modelContext: container.mainContext)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverRoot()
                .environment(appState)
                .environment(coordinator)
                .modelContainer(modelContainer)
                .frame(width: 380, height: 560)
        } label: {
            MenuBarLabel(
                badgeCount: appState.badgeCount,
                isUrgent: appState.hasUrgentTask
            )
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    let badgeCount: Int
    let isUrgent: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isUrgent {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.red, in: .rect(cornerRadius: 4))
            } else {
                Image(systemName: badgeCount > 0 ? "bell.badge.fill" : "bell.fill")
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }
}
