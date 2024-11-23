//
//  PostureTypes.swift
//  Posture
//
//  Created by Chaitanya Rajeev on 11/20/24.
//

// Create a new file called PostureTypes.swift
import Foundation

public enum PostureDirection: String, Codable {
    case forward = "Forward"
    case backward = "Backward"
    case neutral = "Neutral"
    case left = "Left"
    case right = "Right"
    
    public var isGoodPosture: Bool {
        return self == .neutral
    }
}

public struct PostureStatus: Codable {
    public let angle: Double
    public let direction: PostureDirection
    public let rawAngle: Double
    public let yawAngle: Double // Added for left/right movement
    
    public init(angle: Double, direction: PostureDirection, rawAngle: Double, yawAngle: Double = 0.0) {
        self.angle = angle
        self.direction = direction
        self.rawAngle = rawAngle
        self.yawAngle = yawAngle
    }
}
