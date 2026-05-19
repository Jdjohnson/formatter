import Foundation

final class ExternalTriggerService {
    private var isRegistered = false
    private var observer: NSObjectProtocol?
    private let notificationName = "com.jaradjohnson.formatter.format-selection"

    func start(handler: @escaping () -> Void) {
        guard !isRegistered else { return }
        guard isEnabledForCurrentBuildAndEnvironment else {
            FileEventLog.append("external_trigger_disabled")
            return
        }

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

    private var isEnabledForCurrentBuildAndEnvironment: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["FORMATTER_ENABLE_EXTERNAL_TRIGGER"] == "1"
        #else
        false
        #endif
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
