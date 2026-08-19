import Foundation
import IOKit

@MainActor
final class IOKitChangeMonitor {
    private let notificationPort: IONotificationPortRef
    private var iterators: [io_iterator_t] = []
    private let onChange: @MainActor () -> Void
    private var isStarting = true

    init(onChange: @escaping @MainActor () -> Void) {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            preconditionFailure("IONotificationPortCreate failed")
        }
        notificationPort = port
        self.onChange = onChange

        if let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        for serviceClass in Self.serviceClasses {
            register(kIOFirstMatchNotification, serviceClass: serviceClass)
            register(kIOTerminatedNotification, serviceClass: serviceClass)
        }
        isStarting = false
    }

    isolated deinit {
        for iterator in iterators { IOObjectRelease(iterator) }
        IONotificationPortDestroy(notificationPort)
    }

    private func register(_ notification: String, serviceClass: String) {
        guard let matching = IOServiceMatching(serviceClass) else { return }
        var iterator: io_iterator_t = 0
        let result = IOServiceAddMatchingNotification(
            notificationPort,
            notification,
            matching,
            Self.callback,
            Unmanaged.passUnretained(self).toOpaque(),
            &iterator
        )
        guard result == KERN_SUCCESS else { return }
        iterators.append(iterator)
        handle(iterator: iterator)
    }

    nonisolated private static let callback: IOServiceMatchingCallback = { context, iterator in
        guard let context else { return }
        let monitor = Unmanaged<IOKitChangeMonitor>.fromOpaque(context).takeUnretainedValue()
        monitor.receive(iterator: iterator)
    }

    nonisolated private func receive(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
        precondition(Thread.isMainThread)
        MainActor.assumeIsolated {
            guard !isStarting else { return }
            onChange()
        }
    }

    private func handle(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }

    private static let serviceClasses = ["IOUSBHostDevice", "IOSerialBSDClient"]
}
