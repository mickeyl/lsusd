public enum USBDeviceDisplayState: Hashable, Sendable {
    case unchanged
    case added
    case removed
}

public struct USBDeviceDisplayItem: Identifiable, Hashable, Sendable {
    public let id: USBDevice.ID
    public let device: USBDevice
    public let state: USBDeviceDisplayState

    public init(
        id: USBDevice.ID? = nil,
        device: USBDevice,
        state: USBDeviceDisplayState
    ) {
        self.id = id ?? device.id
        self.device = device
        self.state = state
    }
}

public struct USBDeviceDisplayCycle: Sendable {
    private var baselineIdentities: Set<USBDeviceDisplayIdentity> = []
    private var currentIdentities: Set<USBDeviceDisplayIdentity> = []
    private var knownDevices: [USBDeviceDisplayIdentity: USBDevice] = [:]
    private var displayIDs: [USBDeviceDisplayIdentity: USBDevice.ID] = [:]
    private var orderedIdentities: [USBDeviceDisplayIdentity] = []

    public init(devices: [USBDevice] = []) {
        reset(to: devices)
    }

    public var items: [USBDeviceDisplayItem] {
        orderedIdentities.compactMap { identity in
            guard let id = displayIDs[identity],
                  let device = knownDevices[identity] else {
                return nil
            }
            let state: USBDeviceDisplayState
            if !currentIdentities.contains(identity) {
                state = .removed
            } else if !baselineIdentities.contains(identity) {
                state = .added
            } else {
                state = .unchanged
            }
            return USBDeviceDisplayItem(id: id, device: device, state: state)
        }
    }

    public mutating func reset(to devices: [USBDevice]) {
        knownDevices = [:]
        displayIDs = [:]
        orderedIdentities = []
        updateKnownDevices(with: devices)
        baselineIdentities = Set(devices.map(\.displayIdentity))
        currentIdentities = baselineIdentities
    }

    public mutating func update(with devices: [USBDevice]) {
        updateKnownDevices(with: devices)
        currentIdentities = Set(devices.map(\.displayIdentity))
    }

    private mutating func updateKnownDevices(with devices: [USBDevice]) {
        for device in devices {
            let identity = device.displayIdentity
            if knownDevices[identity] == nil {
                orderedIdentities.append(identity)
                displayIDs[identity] = device.id
            }
            knownDevices[identity] = device
        }
    }
}

private enum USBDeviceDisplayIdentity: Hashable, Sendable {
    case location(
        id: UInt32,
        vendorID: UInt16,
        productID: UInt16,
        serial: String?,
        deviceNode: String?
    )
    case registry(USBDevice.ID)
}

private extension USBDevice {
    var displayIdentity: USBDeviceDisplayIdentity {
        guard let locationID else { return .registry(id) }
        return .location(
            id: locationID,
            vendorID: vendorID,
            productID: productID,
            serial: serial == "?" ? nil : serial,
            deviceNode: deviceNode
        )
    }
}
