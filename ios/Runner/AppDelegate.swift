import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1. 注册所有插件到主引擎 (必须手动调用，解决 MissingPluginException)
    GeneratedPluginRegistrant.register(with: self)
    
    // 2. 设置通知代理 (FlutterAppDelegate 已经实现了协议，直接赋值即可)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
