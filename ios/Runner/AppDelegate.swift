import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Take over audio session for video playback.
    // .playback category ensures video audio plays through the speaker
    // even when the device silent switch is ON (standard for video apps).
    // .moviePlayback mode optimizes for video content.
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .moviePlayback,
        options: []
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Audio session error: \(error)")
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
