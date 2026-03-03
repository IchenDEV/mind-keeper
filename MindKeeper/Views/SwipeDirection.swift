import Foundation

enum SwipeDirection: Equatable {
    case up, left, right, none

    static func from(offset: CGSize) -> SwipeDirection {
        let absW = abs(offset.width)
        let absH = abs(offset.height)

        if absH > absW && offset.height < -20 {
            return .up
        } else if absW > absH && offset.width < -20 {
            return .left
        } else if absW > absH && offset.width > 20 {
            return .right
        }
        return .none
    }

    static func thresholdMet(direction: SwipeDirection, offset: CGSize) -> Bool {
        switch direction {
        case .up: return offset.height < -40
        case .left: return offset.width < -50
        case .right: return offset.width > 50
        case .none: return false
        }
    }
}
