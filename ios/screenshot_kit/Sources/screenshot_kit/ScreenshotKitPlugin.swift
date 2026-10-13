import Flutter
import UIKit

public class ScreenshotKitPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "screenshot_kit", binaryMessenger: registrar.messenger())
    let instance = ScreenshotKitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "captureScreen" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let window = Self.keyWindow() else {
      result(FlutterError(code: "no_window", message: "No key window to capture.", details: nil))
      return
    }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = window.screen.scale
    let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
    let image = renderer.image { _ in
      window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
    // Drawing must happen on the main thread; encoding can move off it.
    DispatchQueue.global(qos: .userInitiated).async {
      let data = image.pngData()
      DispatchQueue.main.async {
        guard let data = data else {
          result(FlutterError(code: "encode_failed", message: "Could not encode the capture as PNG.", details: nil))
          return
        }
        result(FlutterStandardTypedData(bytes: data))
      }
    }
  }

  private static func keyWindow() -> UIWindow? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let active = scenes.filter { $0.activationState == .foregroundActive }
    for scene in active + scenes {
      if let window = scene.windows.first(where: { $0.isKeyWindow }) {
        return window
      }
    }
    return scenes.first?.windows.first
  }
}
