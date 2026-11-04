import UIKit

extension Notification.Name {
    static let deviceShaken = Notification.Name("deviceShaken")
}

/// Shaking the phone posts `.deviceShaken` (used to add 5 minutes to the
/// sleep timer, like other podcast apps).
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceShaken, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
