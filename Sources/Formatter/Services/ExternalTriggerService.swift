import Foundation

final class ExternalTriggerService {
    private var isRegistered = false
    private var observer: NSObjectProtocol?
    private let notificationName = "com.jaradjohnson.formatter.format-selection"

    func start(handler: @escaping () -> Void) {
        guard !isRegistered else { return }
        FileEventLog.append("external_trigger_start")
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(notificationName),
            object: nil,
            queue: .main
        ) { _ in
            handler()
        }
        isRegistered = true
    }

    func stop() {
        guard isRegistered else { return }
        FileEventLog.append("external_trigger_stop")
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
        isRegistered = false
    }
}
