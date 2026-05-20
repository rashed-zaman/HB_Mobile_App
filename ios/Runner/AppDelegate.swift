import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let channelName = "com.example.hb_sales/device_id"
  private static let prefsKey = "device_id"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DeviceIdChannel")!
    let channel = FlutterMethodChannel(
      name: AppDelegate.channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getOrCreateDeviceId":
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: AppDelegate.prefsKey), !id.isEmpty {
          result(id)
          return
        }
        let id = UUID().uuidString
        defaults.set(id, forKey: AppDelegate.prefsKey)
        result(id)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
