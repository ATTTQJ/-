import Flutter
import UIKit
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    
    // 🌟 连环敲门核心
    static var pendingAction: [String: String]?
    static var retryTimer: Timer?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 不再在这里注册 Channel，避免拿不到 Controller
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }

    // ==========================================
    // 🌟 核心分发中枢：动态捕捉 Flutter 引擎
    // ==========================================
    static func deliverAction(action: String, deviceName: String) {
        pendingAction = ["action": action, "device": deviceName]
        
        DispatchQueue.main.async {
            // 停掉旧的定时器，防止重叠
            retryTimer?.invalidate()
            
            // 每 0.5 秒扫荡一次，直到成功
            retryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                guard let actionData = pendingAction else {
                    timer.invalidate()
                    return
                }
                
                // 🌟 关键修复：每次敲门前，动态去抓取 FlutterViewController！
                // 这样彻底无视了冷启动的延迟问题，只要 Flutter 界面一出来，立马抓住！
                guard let delegate = UIApplication.shared.delegate as? FlutterAppDelegate,
                      let window = delegate.window,
                      let controller = window.rootViewController as? FlutterViewController else {
                    print("⏳ 界面尚未挂载，继续等待...")
                    return
                }
                
                // 抓到引擎后，临时建立通讯频道
                let channel = FlutterMethodChannel(name: "com.fakeuy.water/siri", binaryMessenger: controller.binaryMessenger)
                
                channel.invokeMethod("executeAction", arguments: actionData) { result in
                    // 🌟 只要 Dart 端回复了 "Success"，立刻清空任务并停掉计时器
                    if let res = result as? String, res == "Success" {
                        print("✅ Flutter 成功接收指令并已回执！")
                        pendingAction = nil
                        timer.invalidate()
                    } else {
                        print("⏳ 频道已通，但 Dart 尚未回执，重试中...")
                    }
                }
            }
            retryTimer?.fire()
        }
    }

    // 🌟 URL Scheme 拦截
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
    static var openAppWhenRun: Bool = true // 必须为 true，确保拉起视图

    @Parameter(title: "设备备注") var deviceName: String?

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AppDelegate.deliverAction(action: "start", deviceName: deviceName ?? "")
        return .result(value: "指令下达", dialog: "正在唤醒水控...")
    }
}

@available(iOS 16.0, *)
struct StopWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "停止用水"
    static var openAppWhenRun: Bool = true 

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