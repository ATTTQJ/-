import Flutter
import UIKit
import AppIntents // 🌟 引入 Siri 意图框架

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
// 🌟 以下为 Siri / 快捷指令的原生拦截逻辑
// ==========================================

@available(iOS 16.0, *)
struct StartWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "开启热水"
    
    // 允许在参数中传入设备备注名
    @Parameter(title: "设备备注", description: "你想开启哪个设备的自来水？")
    var deviceName: String?

    // Siri 如何理解这个参数
    static var parameterSummary: some ParameterSummary {
        Summary("在 \(\.$deviceName) 开水")
    }

    // 🌟 Siri 触发时执行的后台逻辑
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // 1. 获取 Flutter 引擎与控制器
        guard let delegate = UIApplication.shared.delegate as? FlutterAppDelegate,
              let controller = delegate.window?.rootViewController as? FlutterViewController else {
            return .result(value: "失败", dialog: "抱歉，App 引擎尚未就绪。")
        }
        
        // 2. 建立与 main.dart 通信的频道
        let channel = FlutterMethodChannel(name: "com.fakeuy.water/siri", binaryMessenger: controller.binaryMessenger)
        let targetDevice = deviceName ?? ""
        
        // 3. 发送带参数的指令给 Dart
        channel.invokeMethod("executeAction", arguments: ["action": "start", "device": targetDevice])
        
        // 4. 返回给 Siri 的语音播报结果
        return .result(value: "指令已发送", dialog: "好的，已为你发送开水指令。")
    }
}

@available(iOS 16.0, *)
struct WaterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWaterIntent(),
            phrases: [
                "使用 \(.applicationName) 在 \(\.$deviceName) 开水",
                "用 \(.applicationName) 开启 \(\.$deviceName)",
                "在 \(\.$deviceName) 开水"
            ],
            shortTitle: "开启热水",
            systemImageName: "drop.fill"
        )
    }
}
