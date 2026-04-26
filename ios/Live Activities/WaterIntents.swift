import ActivityKit
import AppIntents
import Foundation

@available(iOS 17.0, *)
struct StartWaterIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "开始用水"
    static var description = IntentDescription("使用默认设备开始用水")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let auth = WaterIntentStore.authContext()
        guard auth.isValid else {
            throw WaterIntentError.missingAuth
        }
        guard let device = WaterIntentStore.defaultDevice() else {
            throw WaterIntentError.missingDefaultDevice
        }

        let session = try await WaterApiClient(auth: auth).startWater(device: device)
        WaterIntentStore.saveSession(session)
        if #available(iOS 16.1, *) {
            try await WaterLiveActivityController.start(session: session)
        }
        return .result(value: "start", dialog: "已开始用水")
    }
}

@available(iOS 17.0, *)
struct StopWaterIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "结束用水"
    static var description = IntentDescription("结束当前正在用水的设备")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let auth = WaterIntentStore.authContext()
        guard auth.isValid else {
            throw WaterIntentError.missingAuth
        }
        guard let session = WaterIntentStore.activeSession() else {
            throw WaterIntentError.missingActiveSession
        }

        let settlement = try await WaterApiClient(auth: auth).stopWater(session: session)
        WaterIntentStore.clearSession()
        if #available(iOS 16.1, *) {
            await WaterLiveActivityController.finish(session: session, settlement: settlement)
        }
        return .result(value: "stop", dialog: "已关水")
    }
}
