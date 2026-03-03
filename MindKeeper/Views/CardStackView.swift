import SwiftUI
import Combine

struct CardStackView: View {
    @Environment(AppState.self) private var appState
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var scrollAccum: CGSize = .zero
    @State private var eventMonitor: Any?
    @State private var isScrolling = false
    @State private var scrollCommitTask: Task<Void, Never>?

    private let maxScroll: CGFloat = 120

    private var topTask: TaskItem? {
        appState.pendingTasks.first
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            if let task = topTask {
                cardArea(task: task)
                Spacer(minLength: 8)
                actionBar(task: task)
                    .padding(.bottom, 6)
            } else {
                EmptyStateView()
                Spacer(minLength: 8)
            }
        }
        .animation(.spring(.smooth(duration: 0.4, extraBounce: 0.05)), value: appState.pendingTasks.count)
        .onAppear { installScrollMonitor() }
        .onDisappear { removeScrollMonitor() }
    }

    // MARK: - Card

    private func cardArea(task: TaskItem) -> some View {
        TaskCardView(
            task: task,
            dragOffset: effectiveOffset,
            gesturePhase: isActive ? .dragging : .idle
        )
        .contentShape(Rectangle())
        .offset(effectiveOffset)
        .rotationEffect(.degrees(Double(effectiveOffset.width) / 30.0))
        .highPriorityGesture(dragGesture(for: task))
        .padding(.horizontal, 20)
    }

    private var effectiveOffset: CGSize {
        CGSize(
            width: dragOffset.width + scrollAccum.width,
            height: dragOffset.height + scrollAccum.height
        )
    }

    private var isActive: Bool {
        isDragging || isScrolling
    }

    // MARK: - Action Buttons

    private func actionBar(task: TaskItem) -> some View {
        HStack(spacing: 0) {
            actionButton(icon: "clock.arrow.circlepath", label: "延迟", color: .orange) {
                animateAction(.left, task: task)
            }
            actionButton(icon: "checkmark.circle", label: "完成", color: .green) {
                animateAction(.up, task: task)
            }
            actionButton(icon: "xmark", label: "丢弃", color: Color(.tertiaryLabelColor)) {
                animateAction(.right, task: task)
            }
        }
        .padding(.horizontal, 20)
    }

    private func actionButton(
        icon: String, label: String, color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - NSEvent Scroll Monitor

    private func installScrollMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [self] event in
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            DispatchQueue.main.async {
                self.handleScrollDelta(dx: dx, dy: dy)
            }
            return event
        }
    }

    private func removeScrollMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleScrollDelta(dx: CGFloat, dy: CGFloat) {
        guard topTask != nil else { return }
        guard appState.activePanel == .cardStack else { return }
        guard abs(dx) > 0.5 || abs(dy) > 0.5 else { return }

        isScrolling = true

        var tx = Transaction()
        tx.animation = nil
        withTransaction(tx) {
            scrollAccum.width = clamp(scrollAccum.width + dx * 2.5, limit: maxScroll)
            scrollAccum.height = clamp(scrollAccum.height + dy * 2.5, limit: maxScroll)
        }

        scrollCommitTask?.cancel()
        scrollCommitTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            commitScroll()
        }
    }

    private func clamp(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        min(max(value, -limit), limit)
    }

    private func commitScroll() {
        guard let task = topTask else {
            resetAll()
            return
        }

        let direction = SwipeDirection.from(offset: scrollAccum)
        if SwipeDirection.thresholdMet(direction: direction, offset: scrollAccum) {
            animateAction(direction, task: task)
        } else {
            withAnimation(.spring(.smooth(duration: 0.25))) {
                scrollAccum = .zero
                isScrolling = false
            }
        }
    }

    // MARK: - Drag Gesture (click-drag)

    private func dragGesture(for task: TaskItem) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
                let direction = SwipeDirection.from(offset: value.translation)
                if SwipeDirection.thresholdMet(direction: direction, offset: value.translation) {
                    animateAction(direction, task: task)
                } else {
                    withAnimation(.spring(.smooth(duration: 0.3))) {
                        dragOffset = .zero
                        isDragging = false
                    }
                }
            }
    }

    // MARK: - Actions

    private func animateAction(_ direction: SwipeDirection, task: TaskItem) {
        let target = flyAwayOffset(for: direction)
        withAnimation(.spring(.smooth(duration: 0.3))) {
            dragOffset = target
            scrollAccum = .zero
        }
        scrollCommitTask?.cancel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            performAction(direction: direction, task: task)
            resetAll()
        }
    }

    private func performAction(direction: SwipeDirection, task: TaskItem) {
        switch direction {
        case .up: appState.markCompleted(task)
        case .left: appState.markDeferred(task)
        case .right: appState.markDropped(task)
        case .none: break
        }
    }

    private func resetAll() {
        dragOffset = .zero
        scrollAccum = .zero
        isDragging = false
        isScrolling = false
    }

    private func flyAwayOffset(for direction: SwipeDirection) -> CGSize {
        switch direction {
        case .up: CGSize(width: 0, height: -500)
        case .left: CGSize(width: -400, height: 0)
        case .right: CGSize(width: 400, height: 0)
        case .none: .zero
        }
    }
}
