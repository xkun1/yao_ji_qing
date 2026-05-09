import Flutter
import UIKit

@_silgen_name("isar_version")
private func isar_version() -> UnsafePointer<CChar>

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let audioRecorder = DirectAudioRecorder()
  private var audioChannel: FlutterMethodChannel?
  private var audioStreamChannel: FlutterEventChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    _ = isar_version()
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // 注册直接音频录制通道（iOS 端实现）
    if let controller = window?.rootViewController as? FlutterViewController {
      audioChannel = FlutterMethodChannel(
        name: "yao_ji_qing/direct_audio",
        binaryMessenger: controller.binaryMessenger
      )
      audioChannel?.setMethodCallHandler { [weak self] call, result in
        self?.audioRecorder.handle(call, result: result)
      }

      audioStreamChannel = FlutterEventChannel(
        name: "yao_ji_qing/direct_audio_stream",
        binaryMessenger: controller.binaryMessenger
      )
      audioStreamChannel?.setStreamHandler(audioRecorder)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
