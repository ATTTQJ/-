import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct WaterLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var statusText: String
        var startedAt: Date
        var elapsedSeconds: Int
        var amountText: String
        var isRunning: Bool
    }

    var deviceId: String
    var deviceName: String
    var orderNum: String
}
