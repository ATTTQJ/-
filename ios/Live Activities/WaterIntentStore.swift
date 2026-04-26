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
        let hasCurrentDefault = devices.contains { $0.id == currentDefault }
        if !devices.isEmpty && (currentDefault.isEmpty || !hasCurrentDefault) {
            defaults.set(devices[0].id, forKey: Key.defaultDeviceId)
        }
        if devices.isEmpty {
            defaults.removeObject(forKey: Key.defaultDeviceId)
        }
        defaults.synchronize()
    }

    static func setDefaultDevice(id: String) {
        defaults.set(id, forKey: Key.defaultDeviceId)
        defaults.synchronize()
    }

    static func defaultDevice() -> WaterIntentDevice? {
        let devices = deviceCatalog()
        let defaultId = defaults.string(forKey: Key.defaultDeviceId) ?? ""
        if let device = devices.first(where: { $0.id == defaultId }) {
            return device
        }
        return devices.first
    }

    static func deviceCatalog() -> [WaterIntentDevice] {
        guard let data = defaults.data(forKey: Key.catalog),
              let devices = try? JSONDecoder().decode([WaterIntentDevice].self, from: data) else {
            return []
        }
        return devices
    }

    static func saveSession(_ session: WaterIntentSession) {
        let defaults = defaults
        defaults.set(session.orderNum, forKey: Key.orderNum)
        defaults.set(session.tableName, forKey: Key.tableName)
        defaults.set(session.mac, forKey: Key.mac)
        defaults.set(session.deviceId, forKey: Key.deviceId)
        defaults.set(session.deviceName, forKey: Key.deviceName)
        defaults.set(session.isHotWater, forKey: Key.isHotWater)
        defaults.set(session.startedAtMs, forKey: Key.startedAtMs)
        defaults.set(session.initialBalance, forKey: Key.initialBalance)
        defaults.set(session.isRunning, forKey: Key.isRunning)
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
            startedAtMs: Int64(defaults.double(forKey: Key.startedAtMs)),
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
        defaults.synchronize()
    }
}
