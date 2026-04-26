import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var pendingFileURL: URL?
  private var fileChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Capture file URL if app was cold-started via "Open In"
    if let url = launchOptions?[.url] as? URL {
      pendingFileURL = url
    }

    // Set up method channel after Flutter engine is ready
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      fileChannel = FlutterMethodChannel(
        name: "com.example.fengCalendar/file_open",
        binaryMessenger: controller.binaryMessenger
      )
      fileChannel?.setMethodCallHandler { [weak self] call, result in
        if call.method == "getPendingFile" {
          if let url = self?.pendingFileURL {
            // Copy to temp dir so Flutter can read it
            let dest = FileManager.default.temporaryDirectory
              .appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: url, to: dest)
            self?.pendingFileURL = nil
            result(dest.path)
          } else {
            result(nil)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Called when app is already running and user opens a file
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    // Copy to temp dir
    let dest = FileManager.default.temporaryDirectory
      .appendingPathComponent(url.lastPathComponent)
    try? FileManager.default.removeItem(at: dest)
    try? FileManager.default.copyItem(at: url, to: dest)

    fileChannel?.invokeMethod("openFile", arguments: dest.path)
    return true
  }
}
