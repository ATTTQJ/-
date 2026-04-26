import Foundation

enum WaterIntentStore {
    static let appGroupId = "group.com.fakeuy.water"

    private enum Key {
        static let token = "water.auth.token"
        static let userId = "water.auth.userId"
        static let balance = "water.auth.balance"
        static let catalog = "water.devices.catalog"
        static let defaultDeviceId = "water.devices.defaultId"
        static let orderNum = "water.session.orderNum"
        static let tableName = "water.session.tableName"
        static let mac = "water.session.mac"
        static let deviceId = "water.session.deviceId"
        static let deviceName = "water.session.deviceName"
        static let isHotWater = "water.session.isHotWater"
        static let startedAtMs = "water.session.startedAtMs"
        static let initialBalance = "water.session.initialBalance"
        static let isRunning = "water.session.isRunning"
        static let settlementAmount = "water.session.settlementAmount"
        static let settlementElapsedSeconds = "water.session.settlementElapsedSeconds"
        static let settlementBalance = "water.session.settlementBalance"
        static let finishedAtMs = "water.session.finishedAtMs"
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? .standard
    }

    static func saveAuthContext(token: String, userId: String, balance: String) {
        let defaults = defaults
        defaults.set(token, forKey: Key.token)
        defaults.set(userId, forKey: Key.userId)
        defaults.set(balance, forKey: Key.balance)
        defaults.synchronize()
    }

    static func authContext() -> WaterAuthContext {
        WaterAuthContext(
            token: defaults.string(forKey: Key.token) ?? "",
            userId: defaults.string(forKey: Key.userId) ?? "",
            balance: defaults.string(forKey: Key.balance) ?? ""
        )
    }

    static func clearAuthContext() {
        let defaults = defaults
        defaults.removeObject(forKey: Key.token)
        defaults.removeObject(forKey: Key.userId)
        defaults.removeObject(forKey: Key.balance)
        defaults.synchronize()
    }

    static func saveDeviceCatalog(_ devices: [WaterIntentDevice]) {
        let defaults = defaults
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: Key.catalog)
        }

        let currentDefault = defaults.string(forKey: Key.defaultDeviceId) ?? ""
        if devices.isEmpty {
            defaults.removeObject(forKey: Key.defaultDeviceId)
        } else if currentDefault.isEmpty {
            defaults.set(devices[0].id, forKey: Key.defaultDeviceId)
        }
        defaults.synchronize()
    }

    static func setDefaultDevice(id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        defaults.set(trimmed, forKey: Key.defaultDeviceId)
        defaults.synchronize()
    }

    static func defaultDevice() -> WaterIntentDevice? {
        let devices = deviceCatalog()
        let defaultId = defaults.string(forKey: Key.defaultDeviceId) ?? ""
        if defaultId.isEmpty {
            return devices.first
        }
        return devices.first { $0.id == defaultId }
    }

    static func deviceCatalog() -> [WaterIntentDevice] {
        guard let data = defaults.data(forKey: Key.catalog),
              let devices = try? JSONDecoder().decode([WaterIntentDevice].self, from: data) else {
            return []
        }
        return devices
    }

    static func clearDeviceCatalog() {
        let defaults = defaults
        defaults.removeObject(forKey: Key.catalog)
        defaults.removeObject(forKey: Key.defaultDeviceId)
        defaults.synchronize()
    }

    static func saveSession(_ session: WaterIntentSession) {
        let defaults = defaults
        defaults.set(session.orderNum, forKey: Key.orderNum)
        defaults.set(session.tableName, forKey: Key.tableName)
        defaults.set(session.mac, forKey: Key.mac)
        defaults.set(session.deviceId, forKey: Key.deviceId)
        defaults.set(session.deviceName, forKey: Key.deviceName)
        defaults.set(session.isHotWater, forKey: Key.isHotWater)
        defaults.set(NSNumber(value: session.startedAtMs), forKey: Key.startedAtMs)
        defaults.set(session.initialBalance, forKey: Key.initialBalance)
        defaults.set(session.isRunning, forKey: Key.isRunning)
        defaults.removeObject(forKey: Key.settlementAmount)
        defaults.removeObject(forKey: Key.settlementElapsedSeconds)
        defaults.removeObject(forKey: Key.settlementBalance)
        defaults.removeObject(forKey: Key.finishedAtMs)
        defaults.synchronize()
    }

    static func saveFinishedSession(_ session: WaterIntentSession, settlement: WaterSettlement) {
        let defaults = defaults
        defaults.set(session.orderNum, forKey: Key.orderNum)
        defaults.set(session.tableName, forKey: Key.tableName)
        defaults.set(session.mac, forKey: Key.mac)
        defaults.set(session.deviceId, forKey: Key.deviceId)
        defaults.set(session.deviceName, forKey: Key.deviceName)
        defaults.set(session.isHotWater, forKey: Key.isHotWater)
        defaults.set(NSNumber(value: session.startedAtMs), forKey: Key.startedAtMs)
        defaults.set(session.initialBalance, forKey: Key.initialBalance)
        defaults.set(false, forKey: Key.isRunning)
        defaults.set(settlement.amount, forKey: Key.settlementAmount)
        defaults.set(settlement.elapsedSeconds, forKey: Key.settlementElapsedSeconds)
        defaults.set(settlement.balance, forKey: Key.settlementBalance)
        defaults.set(NSNumber(value: nowMillis()), forKey: Key.finishedAtMs)
        if !settlement.balance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults.set(settlement.balance, forKey: Key.balance)
        }
        defaults.synchronize()
    }

    static func activeSession() -> WaterIntentSession? {
        let orderNum = defaults.string(forKey: Key.orderNum) ?? ""
        guard !orderNum.isEmpty, defaults.bool(forKey: Key.isRunning) else {
            return nil
        }

        return WaterIntentSession(
            orderNum: orderNum,
            tableName: defaults.string(forKey: Key.tableName) ?? "",
            mac: defaults.string(forKey: Key.mac) ?? "",
            deviceId: defaults.string(forKey: Key.deviceId) ?? "",
            deviceName: defaults.string(forKey: Key.deviceName) ?? "当前设备",
            isHotWater: defaults.bool(forKey: Key.isHotWater),
            startedAtMs: int64(forKey: Key.startedAtMs),
            initialBalance: defaults.string(forKey: Key.initialBalance) ?? "",
            isRunning: true
        )
    }

    static func clearSession() {
        let defaults = defaults
        defaults.removeObject(forKey: Key.orderNum)
        defaults.removeObject(forKey: Key.tableName)
        defaults.removeObject(forKey: Key.mac)
        defaults.removeObject(forKey: Key.deviceId)
        defaults.removeObject(forKey: Key.deviceName)
        defaults.removeObject(forKey: Key.isHotWater)
        defaults.removeObject(forKey: Key.startedAtMs)
        defaults.removeObject(forKey: Key.initialBalance)
        defaults.removeObject(forKey: Key.isRunning)
        defaults.removeObject(forKey: Key.settlementAmount)
        defaults.removeObject(forKey: Key.settlementElapsedSeconds)
        defaults.removeObject(forKey: Key.settlementBalance)
        defaults.removeObject(forKey: Key.finishedAtMs)
        defaults.synchronize()
    }

    static func sessionSnapshot() -> [String: Any] {
        let defaults = defaults
        let orderNum = defaults.string(forKey: Key.orderNum) ?? ""
        guard !orderNum.isEmpty else {
            return ["state": "none"]
        }

        let isRunning = defaults.bool(forKey: Key.isRunning)
        let startedAtMs = int64(forKey: Key.startedAtMs)
        let isHotWater = defaults.bool(forKey: Key.isHotWater)
        let elapsedSeconds: Int
        if isRunning {
            elapsedSeconds = max(0, Int((nowMillis() - startedAtMs) / 1000))
        } else {
            elapsedSeconds = defaults.integer(forKey: Key.settlementElapsedSeconds)
        }

        return [
            "state": isRunning ? "running" : "finished",
            "orderNum": orderNum,
            "tableName": defaults.string(forKey: Key.tableName) ?? "",
            "mac": defaults.string(forKey: Key.mac) ?? "",
            "deviceId": defaults.string(forKey: Key.deviceId) ?? "",
            "deviceName": defaults.string(forKey: Key.deviceName) ?? "当前设备",
            "isHotWater": isHotWater,
            "billType": isHotWater ? 2 : 1,
            "startedAtMs": startedAtMs,
            "initialBalance": defaults.string(forKey: Key.initialBalance) ?? "",
            "elapsedSeconds": elapsedSeconds,
            "amount": defaults.double(forKey: Key.settlementAmount),
            "amountText": amountText(defaults.double(forKey: Key.settlementAmount)),
            "balance": defaults.string(forKey: Key.settlementBalance) ?? "",
            "finishedAtMs": int64(forKey: Key.finishedAtMs)
        ]
    }

    static func consumeFinishedSession(orderNum: String) {
        let storedOrderNum = defaults.string(forKey: Key.orderNum) ?? ""
        guard !storedOrderNum.isEmpty,
              storedOrderNum == orderNum,
              defaults.bool(forKey: Key.isRunning) == false else {
            return
        }
        clearSession()
    }

    private static func int64(forKey key: String) -> Int64 {
        if let number = defaults.object(forKey: key) as? NSNumber {
            return number.int64Value
        }
        return Int64(defaults.double(forKey: key))
    }

    private static func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private static func amountText(_ amount: Double) -> String {
        "¥\(String(format: "%.2f", max(0, amount)))"
    }
}
