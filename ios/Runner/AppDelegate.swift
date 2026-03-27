import AppIntents
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private static let siriChannelName = "com.fakeuy.water/siri"
    private static let actionKey = "water_action"
    private static let deviceKey = "water_device"
    private static var siriChannel: FlutterMethodChannel?

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
        [
            AppShortcut(
                intent: StartWaterIntent(),
                phrases: [
                    "Start water with \(.applicationName)",
                    "Turn on water with \(.applicationName)"
                ],
                shortTitle: "Start Water",
                systemImageName: "drop.fill"
            ),
            AppShortcut(
                intent: StopWaterIntent(),
                phrases: [
                    "Stop water with \(.applicationName)",
                    "Turn off water with \(.applicationName)"
                ],
                shortTitle: "Stop Water",
                systemImageName: "xmark.circle.fill"
            )
        ]
    }
}
