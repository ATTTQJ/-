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
// 🌟 增强版：带唤醒逻辑的 Siri 意图
// ==========================================

@available(iOS 16.0, *)
struct StartWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "开启热水"
    
    // 设置 openAppWhenRun 为 true，当 App 在后台死掉时，系统会自动尝试拉起引擎
    static var openAppWhenRun: Bool = false 

    @Parameter(title: "设备备注")
    var deviceName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // 1. 尝试获取当前的 Flutter 控制器
        var controller = UIApplication.shared.windows.first?.rootViewController as? FlutterViewController
        
        // 2. 如果控制器不存在，说明引擎完全没启动
        if controller == nil {
            // 这里返回一个特殊的 Dialog 引导用户手动打开一次，或者尝试静默等待
            return .result(value: "请先打开App", dialog: "水控引擎未就绪，请先手动打开一次App。")
        }
        
        // 3. 建立通讯频道
        let channel = FlutterMethodChannel(name: "com.fakeuy.water/siri", binaryMessenger: controller!.binaryMessenger)
        let targetDevice = deviceName ?? ""
        
        // 4. 发送指令给 Dart
        channel.invokeMethod("executeAction", arguments: ["action": "start", "device": targetDevice])
        
        // 5. 提示成功
        return .result(value: "已发送开水指令", dialog: "好的，已为你尝试开启 \(targetDevice) 热水。")
    }
}

@available(iOS 16.0, *)
struct WaterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWaterIntent(),
            phrases: [
                "使用 \(.applicationName) 开启热水",
                "在 \(.applicationName) 里开水",
                "嘿 Siri，用 \(.applicationName) 洗澡"
            ],
            shortTitle: "快速开水",
            systemImageName: "drop.fill"
        )
    }
}
