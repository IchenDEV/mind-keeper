import Foundation
import SwiftData

@MainActor @Observable
final class AppCoordinator {
    let appState: AppState
    private let notificationMonitor = NotificationMonitor()
    private let llmService: LLMService
    private let priorityEngine: PriorityEngine
    private let eventAggregator: EventAggregator
    private let scheduler: LLMScheduler
    private let urgentAlert = UrgentAlertService()
    private var modelContext: ModelContext?
    private var expiryTimer: Task<Void, Never>?
    private var scheduleTimer: Task<Void, Never>?
    private var isRunning = false

    init(appState: AppState) {
        self.appState = appState
        let cloudKey = UserDefaults.standard.string(forKey: "cloudAPIKey")
        let cloudEndpoint = UserDefaults.standard.string(forKey: "cloudEndpoint")
        let ollamaModel = UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3.2"
        self.llmService = LLMService(cloudAPIKey: cloudKey, cloudEndpoint: cloudEndpoint)
        self.priorityEngine = PriorityEngine(
            llmService: llmService,
            memoryStore: appState.memoryStore
        )
        self.eventAggregator = EventAggregator(llmService: llmService)
        self.scheduler = LLMScheduler(llmService: llmService, priorityEngine: priorityEngine)

        Task {
            await llmService.updateConfig(
                cloudAPIKey: cloudKey, cloudEndpoint: cloudEndpoint,
                ollamaModel: ollamaModel
            )
        }
    }

    func reloadLLMConfig() {
        let cloudKey = UserDefaults.standard.string(forKey: "cloudAPIKey")
        let cloudEndpoint = UserDefaults.standard.string(forKey: "cloudEndpoint")
        let ollamaModel = UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3.2"
        Task {
            await llmService.updateConfig(
                cloudAPIKey: cloudKey, cloudEndpoint: cloudEndpoint,
                ollamaModel: ollamaModel
            )
            await llmService.checkOllamaStatus()
            appState.isOllamaAvailable = await llmService.isOllamaReady
        }
    }

    func start(modelContext: ModelContext) {
        guard !isRunning else { return }
        isRunning = true
        self.modelContext = modelContext

        appState.memoryStore.setModelContext(modelContext)
        loadPersistedTasks(from: modelContext)
        seedDemoIfNeeded(context: modelContext)
        startNotificationMonitoring()
        startExpiryTimer()
        startScheduleTimer()
        checkOllamaStatus()
        checkFirstLaunch()
    }

    func loadDemoData() {
        guard let context = modelContext else { return }
        let demos = DemoDataProvider.createDemoTasks()
        for task in demos {
            context.insert(task)
            appState.addTask(task)
        }
        saveContext(context)
        priorityEngine.sortByPriority(&appState.pendingTasks)
    }

    func triggerReschedule() {
        Task {
            await scheduler.reschedule(&appState.pendingTasks)
            checkUrgentTasks()
            if let ctx = modelContext { saveContext(ctx) }
        }
    }

    // MARK: - Private

    private func loadPersistedTasks(from context: ModelContext) {
        let descriptor = FetchDescriptor<TaskItem>(
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        if let all = try? context.fetch(descriptor) {
            appState.pendingTasks = all.filter { $0.status == .pending || $0.status == .aging }
            appState.expiredTasks = all.filter { $0.status == .expired }
            appState.deferredTasks = all.filter { $0.status == .deferred }
            appState.completedTasks = all.filter { $0.status == .completed }
                .sorted { ($0.processedAt ?? .distantPast) > ($1.processedAt ?? .distantPast) }
            appState.droppedTasks = all.filter { $0.status == .dropped }
                .sorted { ($0.processedAt ?? .distantPast) > ($1.processedAt ?? .distantPast) }
        }
    }

    private func seedDemoIfNeeded(context: ModelContext) {
        let hasDemoSeeded = UserDefaults.standard.bool(forKey: "demoSeeded")
        guard !hasDemoSeeded else { return }

        let demos = DemoDataProvider.createDemoTasks()
        for task in demos {
            context.insert(task)
            appState.addTask(task)
        }
        saveContext(context)
        priorityEngine.sortByPriority(&appState.pendingTasks)
        UserDefaults.standard.set(true, forKey: "demoSeeded")
    }

    private func startNotificationMonitoring() {
        Task {
            let hasAccess = await notificationMonitor.checkAccess()
            appState.hasFullDiskAccess = hasAccess
            await notificationMonitor.start { [weak self] records in
                Task { @MainActor [weak self] in
                    self?.handleNewNotifications(records)
                }
            }
        }
    }

    private func handleNewNotifications(_ records: [NotificationRecord]) {
        guard let context = modelContext else { return }
        Task {
            for record in records {
                let aggResult = await eventAggregator.findMatch(
                    for: record,
                    in: appState.pendingTasks
                )

                if aggResult.shouldMerge, let existing = aggResult.matchedTask {
                    eventAggregator.mergeIntoTask(existing, from: record)
                    await priorityEngine.evaluate(existing)
                    priorityEngine.sortByPriority(&appState.pendingTasks)
                } else {
                    let task = record.toTaskItem()
                    context.insert(task)
                    let memoryCtx = appState.memoryStore.buildContext(for: task)
                    await scheduler.evaluateAndInsert(
                        newTask: task,
                        into: &appState.pendingTasks,
                        memoryContext: memoryCtx
                    )
                }
            }

            checkUrgentTasks()
            saveContext(context)
        }
    }

    private func startExpiryTimer() {
        expiryTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                appState.runExpiryCheck()
            }
        }
    }

    private func startScheduleTimer() {
        scheduleTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await scheduler.reschedule(&appState.pendingTasks)
                appState.runExpiryCheck()
                checkUrgentTasks()
                if let ctx = modelContext { saveContext(ctx) }
            }
        }
    }

    private func checkUrgentTasks() {
        if let topUrgent = appState.pendingTasks.first(where: { $0.isUrgent }) {
            urgentAlert.alertIfNeeded(for: topUrgent)
        }
    }

    private func checkOllamaStatus() {
        Task {
            await llmService.checkOllamaStatus()
            appState.isOllamaAvailable = await llmService.isOllamaReady
        }
    }

    private func checkFirstLaunch() {
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunched {
            appState.activePanel = .onboarding
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }

    private func saveContext(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            print("[MindKeeper] SwiftData save failed: \(error.localizedDescription)")
        }
    }
}
