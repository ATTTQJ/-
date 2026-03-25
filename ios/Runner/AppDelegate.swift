import Flutter
import UIKit
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    static var pendingAction: [String: String]?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "com.fakeuy.water/siri", binaryMessenger: controller.binaryMessenger)
            channel.setMethodCallHandler { (call, result) in
                if call.method == "getPendingAction" {
                    result(AppDelegate.fetchAndClearAction())
                } else {
                    result(FlutterMethodNotImplemented)
                }
            }
        }
        return result
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }

    static func saveAction(action: String, device: String) {
        UserDefaults.standard.set(action, forKey: "water_action")
        UserDefaults.standard.set(device, forKey: "water_device")
        UserDefaults.standard.synchronize()
    }

    static func fetchAndClearAction() -> [String: String]? {
        let action = UserDefaults.standard.string(forKey: "water_action")
        let device = UserDefaults.standard.string(forKey: "water_device")
        if let a = action, !a.isEmpty {
            UserDefaults.standard.removeObject(forKey: "water_action")
            UserDefaults.standard.removeObject(forKey: "water_device")
            UserDefaults.standard.synchronize()
            return ["action": a, "device": device ?? ""]
        }
        return nil
    }

    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "waterapp" {
            let action = url.host ?? ""
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let deviceName = components?.queryItems?.first(where: { $0.name == "device" })?.value ?? ""
            AppDelegate.saveAction(action: action, device: deviceName)
            return true
        }
        return super.application(app, open: url, options: options)
    }
}

@available(iOS 16.0, *)
struct StartWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "开启热水"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "设备备注") var deviceName: String?

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AppDelegate.saveAction(action: "start", device: deviceName ?? "")
        return .result(value: "指令已接收", dialog: "正在打开水控...")
    }
}

@available(iOS 16.0, *)
struct StopWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "停止用水"
    static var openAppWhenRun: Bool = true

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AppDelegate.saveAction(action: "stop", device: "")
        return .result(value: "指令已接收", dialog: "正在打开水控...")
    }
}

@available(iOS 16.0, *)
struct WaterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartWaterIntent(), phrases: ["开启热水"], shortTitle: "开启热水", systemImageName: "drop.fill")
        AppShortcut(intent: StopWaterIntent(), phrases: ["停止用水"], shortTitle: "停止用水", systemImageName: "xmark.circle.fill")
    }
}