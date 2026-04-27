import ActivityKit
import AppIntents
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private static let liveActivityChannelName = "com.fakeuy.water/live_activity"
    private static let shortcutContextChannelName = "com.fakeuy.water/shortcut_context"
    private static var liveActivityChannel: FlutterMethodChannel?
    private static var shortcutContextChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        Self.registerChannelsIfNeeded(rootViewController: window?.rootViewController)
        return result
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if url.scheme == "waterapp" {
            return true
        }
        return super.application(app, open: url, options: options)
    }

    static func registerChannelsIfNeeded(rootViewController: UIViewController?) {
        guard let flutterViewController = rootViewController as? FlutterViewController else {
            return
        }

        registerLiveActivityChannelIfNeeded(
            binaryMessenger: flutterViewController.binaryMessenger
        )
        registerShortcutContextChannelIfNeeded(
            binaryMessenger: flutterViewController.binaryMessenger
        )
    }

    private static func registerLiveActivityChannelIfNeeded(
        binaryMessenger: FlutterBinaryMessenger
    ) {
        let channel = FlutterMethodChannel(
            name: liveActivityChannelName,
            binaryMessenger: binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            guard #available(iOS 16.1, *) else {
                result(["ok": false, "reason": "unsupported"])
                return
            }

            let arguments = call.arguments as? [String: Any] ?? [:]
            switch call.method {
            case "startWater":
                Task {
                    do {
                        let session = sessionFromFlutterArguments(arguments)
                        try await WaterLiveActivityController.start(session: session)
                        WaterIntentStore.saveSession(session)
                        result(["ok": true])
                    } catch {
                        result(
                            FlutterError(
                                code: "live_activity_start_failed",
                                message: error.localizedDescription,
                                details: nil
                            )
                        )
                    }
                }
            case "updateWater":
                Task {
                    await WaterLiveActivityController.updateRunning(
                        orderNum: stringValue(arguments["orderNum"]),
                        startedAt: dateValue(arguments["startTimeMillis"]) ?? Date(),
                        elapsedSeconds: intValue(arguments["elapsedSeconds"])
                    )
                    result(["ok": true])
                }
            case "endWater":
                Task {
                    let orderNum = stringValue(arguments["orderNum"])
                    if let session = WaterIntentStore.activeSession(),
                       orderNum.isEmpty || session.orderNum == orderNum {
                        let settlement = WaterSettlement(
                            amount: parseAmountText(stringValue(arguments["amountText"])),
                            elapsedSeconds: intValue(arguments["elapsedSeconds"])
                        )
                        await WaterLiveActivityController.finish(session: session, settlement: settlement)
                        WaterIntentStore.clearSession()
                    } else {
                        await WaterLiveActivityController.endMatching(orderNum: orderNum)
                    }
                    result(["ok": true])
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        liveActivityChannel = channel
    }

    private static func registerShortcutContextChannelIfNeeded(
        binaryMessenger: FlutterBinaryMessenger
    ) {
        let channel = FlutterMethodChannel(
            name: shortcutContextChannelName,
            binaryMessenger: binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            let arguments = call.arguments as? [String: Any] ?? [:]

            switch call.method {
            case "syncAuthContext":
                WaterIntentStore.saveAuthContext(
                    token: stringValue(arguments["token"]),
                    userId: stringValue(arguments["userId"]),
                    balance: stringValue(arguments["balance"])
                )
                result(["ok": true])
            case "syncDeviceCatalog":
                let devices = decodeDevicesJson(stringValue(arguments["devicesJson"]))
                WaterIntentStore.saveDeviceCatalog(devices)
                result(["ok": true])
            case "setDefaultDevice":
                let deviceId = stringValue(arguments["deviceId"])
                WaterIntentStore.setDefaultDevice(id: deviceId)
                result(["ok": true])
            case "getWaterSessionSnapshot":
                result(WaterIntentStore.sessionSnapshot())
            case "consumeFinishedWaterSession":
                let orderNum = stringValue(arguments["orderNum"])
                WaterIntentStore.consumeFinishedSession(orderNum: orderNum)
                result(["ok": true])
            case "clearShortcutContext":
                WaterIntentStore.clearSession()
                WaterIntentStore.clearAuthContext()
                WaterIntentStore.clearDeviceCatalog()
                result(["ok": true])
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        shortcutContextChannel = channel
    }

    @available(iOS 16.1, *)
    private static func sessionFromFlutterArguments(_ arguments: [String: Any]) -> WaterIntentSession {
        let startTimeMillis = int64Value(arguments["startTimeMillis"])
        let deviceName = stringValue(arguments["deviceName"], fallback: "当前设备")
        let billType = intValue(arguments["billType"])

        return WaterIntentSession(
            orderNum: stringValue(arguments["orderNum"]),
            tableName: stringValue(arguments["tableName"]),
            mac: stringValue(arguments["mac"]),
            deviceId: stringValue(arguments["deviceId"]),
            deviceName: deviceName,
            isHotWater: billType == 2,
            startedAtMs: startTimeMillis > 0 ? startTimeMillis : Int64(Date().timeIntervalSince1970 * 1000),
            initialBalance: stringValue(arguments["initialBalance"]),
            isRunning: true
        )
    }

    private static func decodeDevicesJson(_ value: String) -> [WaterIntentDevice] {
        guard let data = value.data(using: .utf8),
              let rawItems = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return rawItems.compactMap { item in
            let id = stringValue(item["id"])
            guard !id.isEmpty else {
                return nil
            }
            return WaterIntentDevice(
                id: id,
                name: stringValue(item["name"], fallback: "当前设备"),
                billType: intValue(item["billType"])
            )
        }
    }

    private static func stringValue(_ value: Any?, fallback: String = "") -> String {
        let text = value.map { "\($0)" } ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func intValue(_ value: Any?) -> Int {
        if let value = value as? Int {
            return value
        }
        if let value = value as? Int64 {
            return Int(value)
        }
        if let value = value as? Double {
            return Int(value)
        }
        return Int(stringValue(value)) ?? 0
    }

    private static func int64Value(_ value: Any?) -> Int64 {
        if let value = value as? Int64 {
            return value
        }
        if let value = value as? Int {
            return Int64(value)
        }
        if let value = value as? Double {
            return Int64(value)
        }
        return Int64(stringValue(value)) ?? 0
    }

    private static func dateValue(_ value: Any?) -> Date? {
        let millis = int64Value(value)
        if millis <= 0 {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
    }

    private static func parseAmountText(_ value: String) -> Double {
        let filtered = value.filter { char in
            char.isNumber || char == "." || char == "-"
        }
        return Double(String(filtered)) ?? 0
    }
}

@available(iOS 17.0, *)
struct WaterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWaterIntent(),
            phrases: [
                "开始用水\(.applicationName)",
                "开水\(.applicationName)",
                "用\(.applicationName)开\(\.$device)"
            ],
            shortTitle: "开始用水",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: StopWaterIntent(),
            phrases: [
                "结束用水\(.applicationName)",
                "关水\(.applicationName)"
            ],
            shortTitle: "结束用水",
            systemImageName: "xmark.circle.fill"
        )
    }
}
