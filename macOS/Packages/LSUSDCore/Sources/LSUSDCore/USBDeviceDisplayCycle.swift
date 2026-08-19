public enum USBDeviceDisplayState: Hashable, Sendable {
    case unchanged
    case added
    case removed
}

public struct USBDeviceDisplayItem: Identifiable, Hashable, Sendable {
    public let device: USBDevice
    public let state: USBDeviceDisplayState

    public var id: USBDevice.ID { device.id }
}

public struct USBDeviceDisplayCycle: Sendable {
    private var baselineIDs: Set<USBDevice.ID> = []
    private var currentIDs: Set<USBDevice.ID> = []
    private var knownDevices: [USBDevice.ID: USBDevice] = [:]
    private var orderedIDs: [USBDevice.ID] = []

    public init(devices: [USBDevice] = []) {
        reset(to: devices)
    }

    public var items: [USBDeviceDisplayItem] {
        orderedIDs.compactMap { id in
            guard let device = knownDevices[id] else { return nil }
            let state: USBDeviceDisplayState
            if !currentIDs.contains(id) {
                state = .removed
            } else if !baselineIDs.contains(id) {
                state = .added
            } else {
                state = .unchanged
            }
            return USBDeviceDisplayItem(device: device, state: state)
        }
    }

    public mutating func reset(to devices: [USBDevice]) {
        baselineIDs = Set(devices.map(\.id))
        currentIDs = baselineIDs
        knownDevices = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        orderedIDs = devices.map(\.id)
    }

    public mutating func update(with devices: [USBDevice]) {
        currentIDs = Set(devices.map(\.id))
        for device in devices {
            if knownDevices[device.id] == nil {
                orderedIDs.append(device.id)
            }
            knownDevices[device.id] = device
        }
    }
}
