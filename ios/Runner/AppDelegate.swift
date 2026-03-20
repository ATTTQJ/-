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
}

// ==========================================
// 🌟 修复版：符合 iOS 26 严格规范的 Siri 意图
// ==========================================

@available(iOS 16.0, *)
struct StartWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "开启热水"
    
    // 🌟 核心修复1：在快捷指令的短语中，系统限制了动态字符串的使用。
    // 我们先定义一个可选参数，但不强行要求 Siri 实时填充它。
    @Parameter(title: "设备备注")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let delegate = UIApplication.shared.delegate as? FlutterAppDelegate,
              let controller = delegate.window?.rootViewController as? FlutterViewController else {
            return .result(value: "失败", dialog: "App 引擎未就绪")
        }
        
        let channel = FlutterMethodChannel(name: "com.fakeuy.water/siri", binaryMessenger: controller.binaryMessenger)
        let targetDevice = deviceName ?? ""
        
        channel.invokeMethod("executeAction", arguments: ["action": "start", "device": targetDevice])
        
        return .result(value: "指令已发送", dialog: "好的，已为你发送开水指令。")
    }
}

@available(iOS 16.0, *)
struct WaterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWaterIntent(),
            phrases: [
                // 🌟 核心修复2：必须包含 (.applicationName)，且移除不符合规范的变量插值
                "使用 \(.applicationName) 开启热水",
                "在 \(.applicationName) 里开水",
                "嘿 Siri，用 \(.applicationName) 洗澡"
            ],
            shortTitle: "快速开水",
            systemImageName: "drop.fill"
        )
    }
}
