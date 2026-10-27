import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var accessibilityChannel: FlutterMethodChannel?
  private var transparencyObserver: NSObjectProtocol?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "YikeSystemSurfaces") {
      YikeSystemSurfaces.shared.install(registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "YikeAccessibility") {
      let channel = FlutterMethodChannel(name: "yike/accessibility", binaryMessenger: registrar.messenger())
      accessibilityChannel = channel
      channel.setMethodCallHandler { call, result in
        if call.method == "reduceTransparency" {
          result(UIAccessibility.isReduceTransparencyEnabled)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      transparencyObserver = NotificationCenter.default.addObserver(
        forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
        object: nil, queue: .main
      ) { [weak channel] _ in
        channel?.invokeMethod("reduceTransparencyChanged", arguments: UIAccessibility.isReduceTransparencyEnabled)
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "YikeNotifications") {
      let channel = FlutterMethodChannel(name: "yike/notifications", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        let center = UNUserNotificationCenter.current()
        switch call.method {
        case "cancelPending":
          if let id = call.arguments as? Int { center.removePendingNotificationRequests(withIdentifiers: [String(id)]) }
          result(nil)
        case "removeDelivered":
          if let id = call.arguments as? Int { center.removeDeliveredNotifications(withIdentifiers: [String(id)]) }
          result(nil)
        case "settings":
          let settings: String
          if #available(iOS 16.0, *) { settings = UIApplication.openNotificationSettingsURLString }
          else { settings = UIApplication.openSettingsURLString }
          if let url = URL(string: settings) { UIApplication.shared.open(url) }
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
