import Flutter
import UIKit
import GoogleMaps
import flutter_config_plus

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let apiKey = FlutterConfigPlusPlugin.env(for: "GOOGLE_MAPS_API_KEY") {
        GMSServices.provideAPIKey(apiKey)
    } else {
        print("WARNING: GOOGLE_MAPS_API_KEY not found in .env file")
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
