import Flutter
import UIKit
import os.proc

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let memoryChannelName = "com.example.appintern/device_memory"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      setupMemoryChannel(messenger: messenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func setupMemoryChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: memoryChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getMemoryInfo" {
        let availBytes = os_proc_available_memory()
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let availMb = Int(availBytes / (1024 * 1024))
        let totalMb = Int(totalBytes / (1024 * 1024))
        let isLowMemory = availMb < 300
        result([
          "availMemMb": availMb,
          "totalMemMb": totalMb,
          "isLowMemory": isLowMemory,
          "thresholdMb": 300
        ])
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
