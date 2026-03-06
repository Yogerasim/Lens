import SwiftUI

@main
struct LensApp: App {

  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var mediaStore = AppMediaStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(mediaStore)
    }
  }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    .portrait
  }
}
