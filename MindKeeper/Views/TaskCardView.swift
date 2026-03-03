import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    let dragOffset: CGSize
    let gesturePhase: GesturePhase

    enum GesturePhase {
        case idle, dragging, committed
    }

    private var swipeDirection: SwipeDirection {
        SwipeDirection.from(offset: dragOffset)
    }

    var body: some View {
        ZStack {
            cardContent
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 150)
                .glassEffect(in: .rect(cornerRadius: 16))
                .overlay { swipeTintOverlay }
                .overlay { urgentBorder }

            if gesturePhase == .dragging {
                swipeLabel
            }
        }
    }

    @ViewBuilder
    private var urgentBorder: some View {
        if task.isUrgent {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.red.opacity(0.6), lineWidth: 1.5)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            sourceRow
            Spacer().frame(height: 10)
            titleSection
            if task.isAggregated {
                Spacer().frame(height: 6)
                subNotificationsPreview
            }
            Spacer(minLength: 8)
            tagsRow
        }
    }

    private var sourceRow: some View {
        HStack(spacing: 6) {
            if task.source == .manual {
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            } else {
                AppIconView(bundleId: task.appBundleId, size: 18)
            }

            Text(task.appName ?? "手动任务")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if task.isAggregated {
                Text("\(task.notificationCount)条通知")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.blue.opacity(0.12), in: .capsule)
                    .foregroundStyle(.blue)
            }

            Spacer(minLength: 4)

            Text(task.createdAt.relativeDisplay)
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            if !task.body.isEmpty {
                Text(task.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var subNotificationsPreview: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(task.subNotifications.suffix(2)) { sub in
                HStack(spacing: 4) {
                    Circle()
                        .fill(.blue.opacity(0.4))
                        .frame(width: 4, height: 4)
                    Text(sub.title.isEmpty ? sub.body : sub.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if task.subNotifications.count > 2 {
                Text("还有 \(task.subNotifications.count - 2) 条相关通知")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var tagsRow: some View {
        HStack(alignment: .center, spacing: 6) {
            if task.isUrgent {
                UrgentHighPill()
            }
            if let category = task.category {
                CategoryPill(category: category)
            }
            if !task.isUrgent && task.urgency >= 7 {
                UrgentPill()
            }
            Spacer(minLength: 4)
            PriorityDots(level: priorityLevel)
        }
    }

    private var priorityLevel: Int {
        max(1, Int((task.priority / 10.0 * 5.0).rounded().clamped(to: 1...5)))
    }

    // MARK: - Swipe Feedback

    private var swipeTintOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(swipeTintColor)
            .allowsHitTesting(false)
    }

    private var swipeTintColor: Color {
        guard gesturePhase == .dragging else { return .clear }
        let p = progressForSwipe
        guard p > 0.15 else { return .clear }
        switch swipeDirection {
        case .up:    return .green.opacity(p * 0.15)
        case .left:  return .orange.opacity(p * 0.15)
        case .right: return .gray.opacity(p * 0.12)
        default:     return .clear
        }
    }

    private var progressForSwipe: Double {
        let travel = max(abs(dragOffset.width), abs(dragOffset.height))
        return min(travel / 100.0, 1.0)
    }

    @ViewBuilder
    private var swipeLabel: some View {
        let p = progressForSwipe
        if p > 0.2 {
            Group {
                switch swipeDirection {
                case .up:    swipeBadge("checkmark.circle.fill", "完成", .green)
                case .left:  swipeBadge("clock.fill", "延迟", .orange)
                case .right: swipeBadge("xmark.circle.fill", "丢弃", .secondary)
                default:     EmptyView()
                }
            }
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(.smooth(duration: 0.2)), value: swipeDirection)
        }
    }

    private func swipeBadge(_ icon: String, _ text: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 28))
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(color)
    }
}

// MARK: - Supporting Views

private struct CategoryPill: View {
    let category: TaskCategory

    var body: some View {
        Text(category.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: .capsule)
            .foregroundStyle(color)
    }

    private var color: Color {
        switch category {
        case .work: .blue
        case .social: .purple
        case .system: .gray
        case .finance: .green
        case .health: .pink
        case .shopping: .orange
        case .other: .secondary
        }
    }
}

private struct UrgentHighPill: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 8))
            Text("高优加急")
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(.red, in: .capsule)
        .foregroundStyle(.white)
    }
}

private struct UrgentPill: View {
    var body: some View {
        Text("紧急")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.red.opacity(0.12), in: .capsule)
            .foregroundStyle(.red)
    }
}

private struct PriorityDots: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < level ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 5, height: 5)
            }
        }
    }
}

extension Date {
    var relativeDisplay: String {
        let interval = Date().timeIntervalSince(self)
        switch interval {
        case ..<60: return "刚刚"
        case ..<3600: return "\(Int(interval / 60))分钟前"
        case ..<86400: return "\(Int(interval / 3600))小时前"
        default: return "\(Int(interval / 86400))天前"
        }
    }
}
