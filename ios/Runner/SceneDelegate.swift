import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        AppDelegate.registerSiriChannelIfNeeded(rootViewController: window?.rootViewController)

        if let url = connectionOptions.urlContexts.first?.url {
            _ = AppDelegate.handleIncomingURL(url)
        }
    }

    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url, AppDelegate.handleIncomingURL(url) {
            return
        }
        super.scene(scene, openURLContexts: URLContexts)
    }
}
