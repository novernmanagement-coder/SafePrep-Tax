import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // Exposes a method channel that lets Dart ask "is this device
  // running a TestFlight/sandbox build?" by checking whether the
  // on-device App Store receipt file is named "sandboxReceipt"
  // (TestFlight/sandbox) vs the production receipt filename. See
  // IAPService._isSandboxEnvironment() in the Dart code for the caller.
  //
  // This used to live in AppDelegate.didFinishLaunchingWithOptions,
  // force-casting window?.rootViewController — but this project uses
  // the Scene-based iOS lifecycle (see Info.plist's
  // UIApplicationSceneManifest), so the window/root view controller
  // don't exist yet at that point in AppDelegate; they're created
  // here, in the scene delegate, once the scene actually connects.
  // The force-cast there was reading a nil window and crashing on
  // every single launch — moving the setup here is the fix.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let receiptChannel = FlutterMethodChannel(
        name: "com.geraldmiller.safepreptax/receipt",
        binaryMessenger: controller.binaryMessenger
    )
    receiptChannel.setMethodCallHandler { (call, result) in
        if call.method == "isSandboxReceipt" {
            let receiptURL = Bundle.main.appStoreReceiptURL
            let isSandbox = receiptURL?.lastPathComponent == "sandboxReceipt"
            result(isSandbox)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
  }
}
