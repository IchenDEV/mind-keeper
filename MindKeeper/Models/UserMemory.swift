import Foundation
import SwiftData

@Model
final class UserMemory {
    var id: UUID
    var dimension: String
    var key: String

    var totalCount: Int
    var completedCount: Int
    var droppedCount: Int
    var deferredCount: Int
    var expiredCount: Int

    var avgResponseTime: Double
    var priorityDelta: Double

    var updatedAt: Date

    init(dimension: String, key: String) {
        self.id = UUID()
        self.dimension = dimension
        self.key = key
        self.totalCount = 0
        self.completedCount = 0
        self.droppedCount = 0
        self.deferredCount = 0
        self.expiredCount = 0
        self.avgResponseTime = 0
        self.priorityDelta = 0
        self.updatedAt = Date()
    }

    var dropRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(droppedCount) / Double(totalCount)
    }

    var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    func memoryAdjustment() -> Double {
        let dropPenalty = -dropRate * 3.0
        let completionBoost = completionRate * 2.0
        let expiredPenalty = totalCount > 0 ? -Double(expiredCount) / Double(totalCount) * 1.5 : 0
        return (dropPenalty + completionBoost + expiredPenalty).clamped(to: -3...3)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
