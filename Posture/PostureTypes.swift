import Foundation

typealias PostureAngle = Double

enum PostureDirection: String, Codable {
    case neutral = "Neutral"
    case forward = "Forward"
    case backward = "Backward"
    case left = "Left"
    case right = "Right"
    
    var description: String {
        switch self {
        case .neutral:
            return "Good Posture"
        case .forward:
            return "Looking Down"
        case .backward:
            return "Looking Up"
        case .left:
            return "Looking Left"
        case .right:
            return "Looking Right"
        }
    }
}

struct PostureStatus: Equatable, Codable {
    let angle: PostureAngle
    let direction: PostureDirection
    let rawAngle: PostureAngle
    let yawAngle: PostureAngle
    
    init(angle: PostureAngle, direction: PostureDirection, rawAngle: PostureAngle, yawAngle: PostureAngle) {
        self.angle = angle
        self.direction = direction
        self.rawAngle = rawAngle
        self.yawAngle = yawAngle
    }
    
    var isGood: Bool {
        return direction == .neutral
    }
}

struct PostureRecord: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let angle: PostureAngle
    let direction: PostureDirection
    let rawAngle: PostureAngle
    let yawAngle: PostureAngle
    
    init(timestamp: Date, angle: PostureAngle, direction: PostureDirection, rawAngle: PostureAngle, yawAngle: PostureAngle) {
        self.timestamp = timestamp
        self.angle = angle
        self.direction = direction
        self.rawAngle = rawAngle
        self.yawAngle = yawAngle
    }
}
