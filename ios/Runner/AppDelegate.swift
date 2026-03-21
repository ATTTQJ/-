import Flutter
import UIKit
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }

    // 🌟 方案 B 核心：处理 waterapp:// 协议跳转
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "waterapp" {
            let action = url.host ?? "" // 获取 start 或 stop
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let deviceName = components?.queryItems?.first(where: { $0.name == "device" })?.value ?? ""

            // 给引擎一点点启动时间（如果是冷启动）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if let controller = self.window?.rootViewController as? FlutterViewController {
                    let channel = FlutterMethodChannel(name: "com.fakeuy.water/siri", binaryMessenger: controller.binaryMessenger)
                    channel.invokeMethod("executeAction", arguments: ["action": action, "device": deviceName])
                }
            }
            return true
        }
        return super.application(app, open: url, options: options)
    }
}

// 保持方案 A 的 Siri 意图代码（双保险）
@available(iOS 16.0, *)
struct StartWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "开启热水"
    static var openAppWhenRun: Bool = true 
    @Parameter(title: "设备备注") var deviceName: String?
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard let controller = UIApplication.shared.windows.first?.rootViewController as? FlutterViewController else {
            return .result(value: "启动中", dialog: "正在唤醒水控...")
        }
        let channel = FlutterMethodChannel(name: "com.fakeuy.water/siri", binaryMessenger: controller.binaryMessenger)
        channel.invokeMethod("executeAction", arguments: ["action": "start", "device": deviceName ?? ""])
        return .result(value: "已执行", dialog: "热水已开启。")
    }
}

@available(iOS 16.0, *)
struct StopWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "停止用水"
    static var openAppWhenRun: Bool = true 
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard let controller = UIApplication.shared.windows.first?.rootViewController as? FlutterViewController else {
            return .result(value: "启动中", dialog: "正在关水...")
        }
        let channel = FlutterMethodChannel(name: "com.fakeuy.water/siri", binaryMessenger: controller.binaryMessenger)
        channel.invokeMethod("executeAction", arguments: ["action": "stop"])
        return .result(value: "已下达", dialog: "水源已关闭。")
    }
}

@available(iOS 16.0, *)
struct WaterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartWaterIntent(), phrases: ["使用 \(.applicationName) 开启热水"], shortTitle: "开启热水", systemImageName: "drop.fill")
        AppShortcut(intent: StopWaterIntent(), phrases: ["使用 \(.applicationName) 停止用水"], shortTitle: "停止用水", systemImageName: "xmark.circle.fill")
    }
}
