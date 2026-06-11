import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let channelName = "com.example.hb_sales/device_id"
  private static let prefsKey = "device_id"
  private static let boundDeviceKey = "bound_device_data"
  private static let loginPayloadKey = "login_payload"

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
      case "setDeviceId":
        guard let id = call.arguments as? String, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          result(FlutterError(code: "INVALID_ID", message: "Device id is required", details: nil))
          return
        }
        UserDefaults.standard.set(id.trimmingCharacters(in: .whitespacesAndNewlines), forKey: AppDelegate.prefsKey)
        result(nil)
      case "getBoundDeviceData":
        result(UserDefaults.standard.string(forKey: AppDelegate.boundDeviceKey))
      case "setBoundDeviceData":
        guard let json = call.arguments as? String, !json.isEmpty else {
          result(FlutterError(code: "INVALID_DATA", message: "Bound device data is required", details: nil))
          return
        }
        UserDefaults.standard.set(json, forKey: AppDelegate.boundDeviceKey)
        result(nil)
      case "getLoginPayload":
        result(UserDefaults.standard.string(forKey: AppDelegate.loginPayloadKey))
      case "setLoginPayload":
        guard let json = call.arguments as? String, !json.isEmpty else {
          result(FlutterError(code: "INVALID_DATA", message: "Login payload is required", details: nil))
          return
        }
        UserDefaults.standard.set(json, forKey: AppDelegate.loginPayloadKey)
        result(nil)
      case "clearLoginPayload":
        UserDefaults.standard.removeObject(forKey: AppDelegate.loginPayloadKey)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
