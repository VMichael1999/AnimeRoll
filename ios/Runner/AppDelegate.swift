import AVFoundation
import AVKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var downloadPiPBridge: DownloadPiPBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure the audio session for video playback so iOS allows
    // background audio and Picture-in-Picture in the custom player.
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .moviePlayback,
        options: []
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Failed to configure AVAudioSession: \(error)")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let messenger = engineBridge.pluginRegistry.registrar(forPlugin: "DownloadPiPPlugin")?.messenger() {
      downloadPiPBridge = DownloadPiPBridge(messenger: messenger)
    }
  }
}

private final class DownloadPiPBridge: NSObject, AVPictureInPictureControllerDelegate {
  private let channel: FlutterMethodChannel
  private var player: AVPlayer?
  private var playerLayer: AVPlayerLayer?
  private var pipController: AVPictureInPictureController?
  private var itemStatusObservation: NSKeyValueObservation?
  private var pendingStartResult: FlutterResult?
  private var resumeFlutterOnStop = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "anime_roll/download_pip",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      start(arguments: call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(arguments: Any?, result: @escaping FlutterResult) {
    guard AVPictureInPictureController.isPictureInPictureSupported() else {
      result(FlutterError(code: "unsupported", message: "PiP is not supported", details: nil))
      return
    }
    guard pendingStartResult == nil else {
      result(FlutterError(code: "busy", message: "PiP is already starting", details: nil))
      return
    }
    guard
      let args = arguments as? [String: Any],
      let path = args["path"] as? String,
      !path.isEmpty
    else {
      result(FlutterError(code: "invalid_path", message: "Missing video path", details: nil))
      return
    }
    guard FileManager.default.fileExists(atPath: path) else {
      result(FlutterError(code: "missing_file", message: "Video file not found", details: nil))
      return
    }
    guard let rootView = rootView else {
      result(FlutterError(code: "missing_view", message: "Unable to resolve root view", details: nil))
      return
    }

    cleanup()
    pendingStartResult = result
    resumeFlutterOnStop = false

    let item = AVPlayerItem(url: URL(fileURLWithPath: path))
    let player = AVPlayer(playerItem: item)
    player.actionAtItemEnd = .pause
    self.player = player

    let layer = AVPlayerLayer(player: player)
    layer.videoGravity = .resizeAspect
    layer.frame = rootView.bounds
    rootView.layer.addSublayer(layer)
    playerLayer = layer

    guard let pipController = AVPictureInPictureController(playerLayer: layer) else {
      result(FlutterError(code: "controller_failed", message: "Unable to create PiP controller", details: nil))
      cleanup()
      return
    }
    pipController.delegate = self
    self.pipController = pipController

    let positionMs = (args["positionMs"] as? NSNumber)?.int64Value ?? 0
    if positionMs > 0 {
      player.seek(
        to: CMTime(value: positionMs, timescale: 1000),
        toleranceBefore: .zero,
        toleranceAfter: .zero
      )
    }

    itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
      DispatchQueue.main.async {
        self?.handleItemStatus(item, speed: args["speed"] as? NSNumber)
      }
    }
  }

  private func handleItemStatus(_ item: AVPlayerItem, speed: NSNumber?) {
    switch item.status {
    case .readyToPlay:
      itemStatusObservation = nil
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
        self?.startPictureInPicture(speed: speed)
      }
    case .failed:
      finishStart(
        FlutterError(
          code: "load_failed",
          message: item.error?.localizedDescription ?? "Unable to load video",
          details: nil
        )
      )
      cleanup()
    case .unknown:
      break
    @unknown default:
      break
    }
  }

  private func startPictureInPicture(speed: NSNumber?) {
    guard let player, let pipController else {
      finishStart(FlutterError(code: "missing_player", message: "PiP player is unavailable", details: nil))
      cleanup()
      return
    }
    guard pipController.isPictureInPicturePossible else {
      finishStart(FlutterError(code: "not_possible", message: "PiP is not possible right now", details: nil))
      cleanup()
      return
    }

    let rate = max(0.1, speed?.floatValue ?? 1)
    player.playImmediately(atRate: rate)
    pipController.startPictureInPicture()
    finishStart(true)
  }

  private func finishStart(_ value: Any) {
    pendingStartResult?(value)
    pendingStartResult = nil
  }

  private var rootView: UIView? {
    if #available(iOS 13.0, *) {
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.flatMap(\.windows).first
      return window?.rootViewController?.view
    }
    return UIApplication.shared.keyWindow?.rootViewController?.view
  }

  private func cleanup() {
    itemStatusObservation = nil
    player?.pause()
    playerLayer?.removeFromSuperlayer()
    pipController?.delegate = nil
    pipController = nil
    playerLayer = nil
    player = nil
    pendingStartResult = nil
  }

  func pictureInPictureControllerDidStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    channel.invokeMethod("started", arguments: nil)
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    finishStart(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
    channel.invokeMethod("failed", arguments: ["message": error.localizedDescription])
    cleanup()
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    resumeFlutterOnStop = true
    completionHandler(true)
  }

  func pictureInPictureControllerDidStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    let positionMs = Int64(CMTimeGetSeconds(player?.currentTime() ?? .zero) * 1000)
    let shouldResume = resumeFlutterOnStop
    channel.invokeMethod(
      "stopped",
      arguments: [
        "positionMs": max(0, positionMs),
        "resume": shouldResume,
      ]
    )
    cleanup()
  }
}
