import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var captureObserver: NSObjectProtocol?
  private var isSceneSnapshotProtected = false
  private var privacyCoverView: UIView?
  private let privacyCoverText = "Private"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    installPrivacyCoverIfNeeded()
    captureObserver = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: UIScreen.main,
      queue: .main
    ) { [weak self] _ in
      self?.updatePrivacyCoverVisibility()
    }
    updatePrivacyCoverVisibility()
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    isSceneSnapshotProtected = true
    updatePrivacyCoverVisibility()
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    isSceneSnapshotProtected = true
    updatePrivacyCoverVisibility()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    isSceneSnapshotProtected = false
    updatePrivacyCoverVisibility()
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    if let captureObserver {
      NotificationCenter.default.removeObserver(captureObserver)
      self.captureObserver = nil
    }
    super.sceneDidDisconnect(scene)
  }

  private func installPrivacyCoverIfNeeded() {
    guard privacyCoverView == nil, let window else {
      return
    }

    let coverView = UIView(frame: window.bounds)
    coverView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    coverView.backgroundColor = .black
    coverView.isAccessibilityElement = true
    coverView.accessibilityLabel = privacyCoverText
    coverView.accessibilityViewIsModal = true
    coverView.accessibilityElementsHidden = true
    coverView.isHidden = true

    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = privacyCoverText
    label.textColor = .white
    label.textAlignment = .center
    label.font = .preferredFont(forTextStyle: .headline)
    label.adjustsFontForContentSizeCategory = true

    coverView.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: coverView.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: coverView.centerYAnchor),
    ])

    window.addSubview(coverView)
    privacyCoverView = coverView
  }

  private func updatePrivacyCoverVisibility() {
    installPrivacyCoverIfNeeded()
    guard let privacyCoverView else {
      return
    }

    let shouldShowPrivacyCover = isSceneSnapshotProtected || UIScreen.main.isCaptured
    privacyCoverView.isHidden = !shouldShowPrivacyCover
    privacyCoverView.accessibilityElementsHidden = !shouldShowPrivacyCover
    privacyCoverView.isAccessibilityElement = shouldShowPrivacyCover

    if shouldShowPrivacyCover {
      window?.bringSubviewToFront(privacyCoverView)
    }
  }
}
