import Flutter
import UIKit
import GoogleMaps
import FirebaseCore
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var merchantAlarmPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase (safe init for environments where GoogleService-Info.plist is injected at CI time)
    if FirebaseApp.app() == nil {
      if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
        let options = FirebaseOptions(contentsOfFile: filePath) {
        FirebaseApp.configure(options: options)
      } else {
        print("[AppDelegate] GoogleService-Info.plist not found; Firebase initialization skipped.")
      }
    }

    // Google Maps API key from Info.plist (skip unresolved placeholders like $(GOOGLE_MAPS_API_KEY))
    if let rawApiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String {
      let apiKey = rawApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
      if !apiKey.isEmpty && !apiKey.hasPrefix("$(") {
        GMSServices.provideAPIKey(apiKey)
      } else {
        print("[AppDelegate] GOOGLE_MAPS_API_KEY is missing or unresolved; Google Maps SDK not initialized.")
      }
    } else {
      print("[AppDelegate] GOOGLE_MAPS_API_KEY is not defined in Info.plist.")
    }

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let merchantAlarmChannel = FlutterMethodChannel(
        name: "jedechai/alarm_sound",
        binaryMessenger: controller.binaryMessenger
      )

      merchantAlarmChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate deallocated", details: nil))
          return
        }

        switch call.method {
        case "playMerchantAlarm":
          self.playMerchantAlarmSound(result: result)
        case "stopMerchantAlarm":
          self.stopMerchantAlarmSound(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func playMerchantAlarmSound(result: @escaping FlutterResult) {
    guard let url = Bundle.main.url(forResource: "AlertNewOrder", withExtension: "caf") else {
      result(FlutterError(code: "NOT_FOUND", message: "AlertNewOrder.caf not found in bundle", details: nil))
      return
    }

    do {
      // Use playback category so it can play even if device is in silent mode.
      // (If you want to respect silent mode, change to .ambient)
      try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)

      // Stop existing player before starting a new one
      merchantAlarmPlayer?.stop()
      merchantAlarmPlayer = try AVAudioPlayer(contentsOf: url)
      merchantAlarmPlayer?.numberOfLoops = -1
      merchantAlarmPlayer?.volume = 1.0
      merchantAlarmPlayer?.prepareToPlay()

      if merchantAlarmPlayer?.play() == true {
        result(true)
      } else {
        result(FlutterError(code: "PLAY_FAILED", message: "AVAudioPlayer failed to start playback", details: nil))
      }
    } catch {
      result(FlutterError(code: "AUDIO_ERROR", message: "Failed to play merchant alarm: \(error)", details: nil))
    }
  }

  private func stopMerchantAlarmSound(result: @escaping FlutterResult) {
    if let player = merchantAlarmPlayer {
      player.stop()
      merchantAlarmPlayer = nil
    }
    result(true)
  }
}
