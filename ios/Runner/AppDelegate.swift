import Flutter
import UIKit
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    
    // 🌟 智能信箱：只在未响应时保留
    static var pendingAction: [String: String]?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "com.fakeuy.water/siri", binaryMessenger: controller.binaryMessenger)
            
            // 供冷启动的 Flutter 主动拉取
            channel.setMethodCallHandler { (call, result) in
                if call.method == "getPendingAction" {
                    result(AppDelegate.pendingAction)
                    AppDelegate.pendingAction = nil
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

    // ==========================================
    // 🌟 核心分发中枢
    // ==========================================
    static func deliverAction(action: String, device: String) {
        // 1. 存入信箱
        AppDelegate.pendingAction = ["action": action, "device": device]
        
        // 2. 延迟 0.5 秒，尝试推给 Flutter（供热启动使用）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let delegate = UIApplication.shared.delegate as? FlutterAppDelegate,
               let controller = delegate.window?.rootViewController as? FlutterViewController {
                
                let channel = FlutterMethodChannel(name: "com.fakeuy.water/siri", binaryMessenger: controller.binaryMessenger)
                
                channel.invokeMethod("executeAction", arguments: AppDelegate.pendingAction) { res in
                    // 🌟 核心逻辑：只有 Flutter 明确回复 "Success" 时，才清空信箱！
                    // 如果 Flutter 没理我们（冷启动中），参数会一直保留在信箱里等待拉取。
                    if let responseString = res as? String, responseString == "Success" {
                        AppDelegate.pendingAction = nil
                    }
                }
            }
        }
    }

    // 🌟 URL 拦截
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "waterapp" {
            let action = url.host ?? "" 
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let deviceName = components?.queryItems?.first(where: { $0.name == "device" })?.value ?? ""
            
            AppDelegate.deliverAction(action: action, device: deviceName)
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
    static var openAppWhenRun: Bool = true // 必须唤醒App

    @Parameter(title: "设备备注") var deviceName: String?

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AppDelegate.deliverAction(action: "start", device: deviceName ?? "")
        return .result(value: "指令下达", dialog: "正在为您开启热水...")
    }
}

@available(iOS 16.0, *)
struct StopWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "停止用水"
    static var openAppWhenRun: Bool = true 

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AppDelegate.deliverAction(action: "stop", device: "")
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