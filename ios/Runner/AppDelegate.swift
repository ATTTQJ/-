import ActivityKit
import AppIntents
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private static let siriChannelName = "com.fakeuy.water/siri"
    private static let liveActivityChannelName = "com.fakeuy.water/live_activity"
    private static let actionKey = "water_action"
    private static let deviceKey = "water_device"
    private static var siriChannel: FlutterMethodChannel?
    private static var liveActivityChannel: FlutterMethodChannel?
    @available(iOS 16.1, *)
    private static var waterActivity: Activity<WaterLiveActivityAttributes>?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        Self.registerSiriChannelIfNeeded(rootViewController: window?.rootViewController)
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
        if Self.handleIncomingURL(url) {
            return true
        }
        return super.application(app, open: url, options: options)
    }

    static func registerSiriChannelIfNeeded(rootViewController: UIViewController?) {
        guard let flutterViewController = rootViewController as? FlutterViewController else {
            return
        }

        let channel = FlutterMethodChannel(
            name: siriChannelName,
            binaryMessenger: flutterViewController.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "getPendingAction":
                result(fetchAndClearAction())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        siriChannel = channel
        registerLiveActivityChannelIfNeeded(
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
            switch call.method {
            case "startWater":
                guard #available(iOS 16.1, *) else {
                    result(["ok": false, "reason": "unsupported"])
                    return
                }
                let arguments = call.arguments as? [String: Any] ?? [:]
                Task {
                    do {
                        try await startWaterLiveActivity(arguments: arguments)
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
                guard #available(iOS 16.1, *) else {
                    result(["ok": false, "reason": "unsupported"])
                    return
                }
                let arguments = call.arguments as? [String: Any] ?? [:]
                Task {
                    await updateWaterLiveActivity(arguments: arguments)
                    result(["ok": true])
                }
            case "endWater":
                guard #available(iOS 16.1, *) else {
                    result(["ok": false, "reason": "unsupported"])
                    return
                }
                let arguments = call.arguments as? [String: Any] ?? [:]
                Task {
                    await endWaterLiveActivity(arguments: arguments)
                    result(["ok": true])
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        liveActivityChannel = channel
    }

    @available(iOS 16.1, *)
    private static func startWaterLiveActivity(arguments: [String: Any]) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        await endWaterLiveActivity(arguments: arguments)

        let deviceId = stringValue(arguments["deviceId"])
        let deviceName = stringValue(arguments["deviceName"], fallback: "当前设备")
        let orderNum = stringValue(arguments["orderNum"])
        let startTimeMillis = doubleValue(arguments["startTimeMillis"])
        let startedAt = startTimeMillis > 0
            ? Date(timeIntervalSince1970: startTimeMillis / 1000)
            : Date()
        let elapsedSeconds = intValue(arguments["elapsedSeconds"])

        let attributes = WaterLiveActivityAttributes(
            deviceId: deviceId,
            deviceName: deviceName,
            orderNum: orderNum
        )
        let state = WaterLiveActivityAttributes.ContentState(
            statusText: "正在用水",
            startedAt: startedAt,
            elapsedSeconds: elapsedSeconds,
            isRunning: true
        )

        if #available(iOS 16.2, *) {
            waterActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } else {
            waterActivity = try Activity.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
        }
    }

    @available(iOS 16.1, *)
    private static func updateWaterLiveActivity(arguments: [String: Any]) async {
        guard let activity = resolveWaterActivity(arguments: arguments) else {
            return
        }

        let startedAt = dateValue(arguments["startTimeMillis"])
            ?? activity.contentState.startedAt
        let state = WaterLiveActivityAttributes.ContentState(
            statusText: stringValue(arguments["statusText"], fallback: "正在用水"),
            startedAt: startedAt,
            elapsedSeconds: intValue(arguments["elapsedSeconds"]),
            isRunning: boolValue(arguments["isRunning"], fallback: true)
        )

        if #available(iOS 16.2, *) {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        } else {
            await activity.update(using: state)
        }
        waterActivity = activity
    }

    @available(iOS 16.1, *)
    private static func endWaterLiveActivity(arguments: [String: Any]) async {
        let orderNum = stringValue(arguments["orderNum"])
        let targetActivities = Activity<WaterLiveActivityAttributes>.activities
            .filter { activity in
                orderNum.isEmpty || activity.attributes.orderNum == orderNum
            }

        let activities = targetActivities.isEmpty
            ? Activity<WaterLiveActivityAttributes>.activities
            : targetActivities
        let elapsedSeconds = intValue(arguments["elapsedSeconds"])

        for activity in activities {
            let state = WaterLiveActivityAttributes.ContentState(
                statusText: "已关水",
                startedAt: activity.contentState.startedAt,
                elapsedSeconds: elapsedSeconds,
                isRunning: false
            )
            if #available(iOS 16.2, *) {
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            } else {
                await activity.end(using: state, dismissalPolicy: .immediate)
            }
        }

        waterActivity = nil
    }

    @available(iOS 16.1, *)
    private static func resolveWaterActivity(
        arguments: [String: Any]
    ) -> Activity<WaterLiveActivityAttributes>? {
        let orderNum = stringValue(arguments["orderNum"])
        if let waterActivity,
           orderNum.isEmpty || waterActivity.attributes.orderNum == orderNum {
            return waterActivity
        }
        return Activity<WaterLiveActivityAttributes>.activities.first { activity in
            orderNum.isEmpty || activity.attributes.orderNum == orderNum
        }
    }

    private static func stringValue(_ value: Any?, fallback: String = "") -> String {
        let text = value.map { "\($0)" } ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func doubleValue(_ value: Any?) -> Double {
        if let value = value as? Double {
            return value
        }
        if let value = value as? Int {
            return Double(value)
        }
        if let value = value as? Int64 {
            return Double(value)
        }
        return Double(stringValue(value)) ?? 0
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

    private static func boolValue(_ value: Any?, fallback: Bool) -> Bool {
        if let value = value as? Bool {
            return value
        }
        let text = stringValue(value).lowercased()
        if text == "true" || text == "1" {
            return true
        }
        if text == "false" || text == "0" {
            return false
        }
        return fallback
    }

    private static func dateValue(_ value: Any?) -> Date? {
        let millis = doubleValue(value)
        if millis <= 0 {
            return nil
        }
        return Date(timeIntervalSince1970: millis / 1000)
    }

    @discardableResult
    static func handleIncomingURL(_ url: URL) -> Bool {
        guard url.scheme == "waterapp" else {
            return false
        }

        let action = url.host ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let deviceName = components?.queryItems?.first(where: { $0.name == "device" })?.value ?? ""
        saveAction(action: action, device: deviceName)
        return true
    }

    static func saveAction(action: String, device: String) {
        UserDefaults.standard.set(action, forKey: actionKey)
        UserDefaults.standard.set(device, forKey: deviceKey)
        UserDefaults.standard.synchronize()
    }

    static func fetchAndClearAction() -> [String: String]? {
        let action = UserDefaults.standard.string(forKey: actionKey)
        let device = UserDefaults.standard.string(forKey: deviceKey)

        guard let action, !action.isEmpty else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: actionKey)
        UserDefaults.standard.removeObject(forKey: deviceKey)
        UserDefaults.standard.synchronize()
        return [
            "action": action,
            "device": device ?? ""
        ]
    }
}

@available(iOS 16.0, *)
struct StartWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Water"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Device Name")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AppDelegate.saveAction(action: "start", device: deviceName ?? "")
        return .result(
            value: "start",
            dialog: "Opening the water controller."
        )
    }
}

@available(iOS 16.0, *)
struct StopWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Water"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AppDelegate.saveAction(action: "stop", device: "")
        return .result(
            value: "stop",
            dialog: "Opening the water controller."
        )
    }
}

@available(iOS 16.0, *)
struct WaterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWaterIntent(),
            phrases: [
                "Start water with \(.applicationName)",
                "Turn on water with \(.applicationName)"
            ],
            shortTitle: "Start Water",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: StopWaterIntent(),
            phrases: [
                "Stop water with \(.applicationName)",
                "Turn off water with \(.applicationName)"
            ],
            shortTitle: "Stop Water",
            systemImageName: "xmark.circle.fill"
        )
    }
}
