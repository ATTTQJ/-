import ActivityKit
import AppIntents
import Foundation

@available(iOS 17.0, *)
struct WaterDeviceEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "设备"
    static let defaultQuery = WaterDeviceEntityQuery()

    let id: String
    let name: String
    let billType: Int

    init(device: WaterIntentDevice) {
        self.id = device.id
        self.name = device.name
        self.billType = device.billType
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(billType == 2 ? "热水" : "直饮水")",
            image: .init(systemName: billType == 2 ? "flame.fill" : "drop.fill")
        )
    }

    var intentDevice: WaterIntentDevice {
        WaterIntentDevice(id: id, name: name, billType: billType)
    }
}

@available(iOS 17.0, *)
struct WaterDeviceEntityQuery: EntityQuery {
    func entities(for identifiers: [WaterDeviceEntity.ID]) async throws -> [WaterDeviceEntity] {
        let idSet = Set(identifiers)
        return WaterIntentStore.deviceCatalog()
            .filter { idSet.contains($0.id) }
            .map(WaterDeviceEntity.init)
    }

    func suggestedEntities() async throws -> [WaterDeviceEntity] {
        WaterIntentStore.deviceCatalog().map(WaterDeviceEntity.init)
    }

    func defaultResult() async -> WaterDeviceEntity? {
        WaterIntentStore.defaultDevice().map(WaterDeviceEntity.init)
    }
}

@available(iOS 17.0, *)
struct StartWaterIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "开始用水"
    static var description = IntentDescription("选择设备并开始用水")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "设备", requestValueDialog: "选择要开水的设备")
    var device: WaterDeviceEntity?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let auth = WaterIntentStore.authContext()
        guard auth.isValid else {
            throw WaterIntentError.missingAuth
        }

        guard let targetDevice = device?.intentDevice ?? WaterIntentStore.defaultDevice() else {
            throw WaterIntentError.missingDefaultDevice
        }

        let session = try await WaterApiClient(auth: auth).startWater(device: targetDevice)
        WaterIntentStore.saveSession(session)
        try await WaterLiveActivityController.start(session: session)
        return .result(value: "start", dialog: "已开始 \(targetDevice.name)")
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

        await WaterLiveActivityController.markStopping(session: session)
        do {
            let settlement = try await WaterApiClient(auth: auth).stopWater(session: session)
            WaterIntentStore.saveFinishedSession(session, settlement: settlement)
            await WaterLiveActivityController.finish(session: session, settlement: settlement)
            return .result(value: "stop", dialog: "已关水")
        } catch {
            await WaterLiveActivityController.updateRunning(
                orderNum: session.orderNum,
                startedAt: session.startedAt,
                elapsedSeconds: session.elapsedSeconds
            )
            throw error
        }
    }
}
