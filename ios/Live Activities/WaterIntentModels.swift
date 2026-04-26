import Foundation

struct WaterAuthContext {
    let token: String
    let userId: String
    let balance: String

    var isValid: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct WaterIntentDevice: Codable, Hashable {
    let id: String
    let name: String
    let billType: Int

    var isHotWater: Bool {
        billType == 2
    }
}

struct WaterIntentSession: Codable, Hashable {
    let orderNum: String
    let tableName: String
    let mac: String
    let deviceId: String
    let deviceName: String
    let isHotWater: Bool
    let startedAtMs: Int64
    let initialBalance: String
    let isRunning: Bool

    var startedAt: Date {
        Date(timeIntervalSince1970: TimeInterval(startedAtMs) / 1000)
    }

    var elapsedSeconds: Int {
        max(0, Int(Date().timeIntervalSince(startedAt)))
    }
}

struct WaterSettlement: Hashable {
    let amount: Double
    let elapsedSeconds: Int

    var amountText: String {
        "¥\(String(format: "%.2f", amount))"
    }
}

enum WaterIntentError: LocalizedError {
    case missingAuth
    case missingDefaultDevice
    case missingActiveSession
    case invalidServerResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingAuth:
            return "请先打开 App 登录"
        case .missingDefaultDevice:
            return "请先在 App 内设置默认设备"
        case .missingActiveSession:
            return "当前没有正在用水的设备"
        case .invalidServerResponse:
            return "服务器返回异常"
        case .server(let message):
            return message.isEmpty ? "请求失败，请稍后重试" : message
        }
    }
}
