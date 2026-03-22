import Flutter
import UIKit
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    
    // 🌟 连环敲门核心
    static var pendingAction: [String: String]?
    static var retryTimer: Timer?
    static var siriChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        if let controller = window?.rootViewController as? FlutterViewController {
            AppDelegate.siriChannel = FlutterMethodChannel(name: "com.fakeuy.water/siri", binaryMessenger: controller.binaryMessenger)
        }
        return result
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }

    // 🌟 核心分发中枢：直到 Flutter 回应才停止发送
    static func deliverAction(action: String, deviceName: String) {
        pendingAction = ["action": action, "device": deviceName]
        
        DispatchQueue.main.async {
            retryTimer?.invalidate()
            retryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                guard let actionData = pendingAction else {
                    timer.invalidate()
                    return
                }
                
                siriChannel?.invokeMethod("executeAction", arguments: actionData) { result in
                    if let res = result as? String, res == "Success" {
                        pendingAction = nil
                        timer.invalidate()
                    }
                }
            }
            retryTimer?.fire()
        }
    }

    // 🌟 URL 拦截
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "waterapp" {
            let action = url.host ?? "" 
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let deviceName = components?.queryItems?.first(where: { $0.name == "device" })?.value ?? ""
            
            AppDelegate.deliverAction(action: action, deviceName: deviceName)
            return true
        }
        return super.application(app, open: url, options: options)
    }
}

// ==========================================
// 🌟 Siri / 快捷指令意图
// ==========================================
@available(iOS 16.0, *)
struct StartWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "开启热水"
    static var openAppWhenRun: Bool = true // 必须为 true，拉起 App 确保成功率

    @Parameter(title: "设备备注") var deviceName: String?

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AppDelegate.deliverAction(action: "start", deviceName: deviceName ?? "")
        return .result(value: "指令下达", dialog: "正在唤醒水控...")
    }
}

@available(iOS 16.0, *)
struct StopWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "停止用水"
    static var openAppWhenRun: Bool = true // 必须为 true

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AppDelegate.deliverAction(action: "stop", deviceName: "")
        return .result(value: "指令下达", dialog: "正在关闭水源...")
    }
}

@available(iOS 16.0, *)
struct WaterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartWaterIntent(), phrases: ["使用 \(.applicationName) 开启热水"], shortTitle: "开启热水", systemImageName: "drop.fill")
        AppShortcut(intent: StopWaterIntent(), phrases: ["使用 \(.applicationName) 停止用水"], shortTitle: "停止用水", systemImageName: "xmark.circle.fill")
    }
}