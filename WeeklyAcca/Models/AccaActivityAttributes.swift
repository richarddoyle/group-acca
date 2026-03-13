import Foundation
import ActivityKit

public struct AccaActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var statusText: String // e.g. "In Progress", "Settled"
        public var correctPicks: Int
        public var totalPicks: Int
        
        // Active Pick
        public var currentPickMatch: String
        public var currentPickSelection: String
        public var currentPickScore: String
        public var currentPickTime: String
        public var currentPickStatus: String // "winning", "losing", "pending"
    }

    public var accaName: String
    public var groupName: String
}
