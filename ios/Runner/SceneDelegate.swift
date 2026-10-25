import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        for context in connectionOptions.urlContexts { _ = YikeSystemSurfaces.shared.receive(context.url) }
    }
    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        let other = URLContexts.filter { !YikeSystemSurfaces.shared.receive($0.url) }
        if !other.isEmpty { super.scene(scene, openURLContexts: Set(other)) }
    }
}
