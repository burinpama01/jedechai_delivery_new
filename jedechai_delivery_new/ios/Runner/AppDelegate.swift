import Flutter
import UIKit
import GoogleMaps
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
