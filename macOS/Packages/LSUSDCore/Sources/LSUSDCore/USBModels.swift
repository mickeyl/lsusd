import Foundation

public struct USBDevice: Identifiable, Codable, Hashable, Sendable {
    public let id: UInt64
    public let bus: Int
    public let address: Int
    public let locationID: UInt32?
    public let product: String
    public let vendor: String
    public let serial: String
    public let vendorID: UInt16
    public let productID: UInt16
    public let releaseValue: UInt16?
    public let linkSpeed: UInt64?
    public let isHub: Bool
    public let deviceClass: UInt8?
    public let deviceNode: String?

    public init(
        id: UInt64,
        bus: Int,
        address: Int,
        locationID: UInt32?,
        product: String,
        vendor: String,
        serial: String,
        vendorID: UInt16,
        productID: UInt16,
        releaseValue: UInt16?,
        linkSpeed: UInt64?,
        isHub: Bool,
        deviceClass: UInt8? = nil,
        deviceNode: String? = nil
    ) {
        self.id = id
        self.bus = bus
        self.address = address
        self.locationID = locationID
        self.product = product.nonEmptyOrUnknown
        self.vendor = vendor.nonEmptyOrUnknown
        self.serial = serial.nonEmptyOrUnknown
        self.vendorID = vendorID
        self.productID = productID
        self.releaseValue = releaseValue
        self.linkSpeed = linkSpeed
        self.isHub = isHub
        self.deviceClass = deviceClass
        self.deviceNode = deviceNode
    }

    public var busText: String { String(format: "%03d", bus) }
    public var addressText: String { String(format: "%03d", address) }
    public var locationText: String {
        locationID.map { String(format: "0x%08x", $0) } ?? "?"
    }
    public var vidpid: String {
        String(format: "%04X:%04X", vendorID, productID)
    }
    public var release: String {
        guard let releaseValue else { return "?" }
        return String(format: "%X.%02X", releaseValue >> 8, releaseValue & 0x00ff)
    }
    public var speed: String {
        guard let linkSpeed else { return "?" }
        return Self.compactSpeed(linkSpeed)
    }
    public var displaySpeed: String {
        speed == "?" ? speed : "\(speed)bit/s"
    }
    public var resolvedDeviceNode: String {
        deviceNode ?? "/dev/bus/usb/\(busText)/\(addressText)"
    }

    private static func compactSpeed(_ bits: UInt64) -> String {
        let units: [(threshold: UInt64, suffix: String)] = [
            (1_000_000_000, "G"),
            (1_000_000, "M"),
            (1_000, "K")
        ]
        guard let unit = units.first(where: { bits >= $0.threshold }) else {
            return String(bits)
        }
        let value = Double(bits) / Double(unit.threshold)
        if value.rounded() == value {
            return "\(Int(value))\(unit.suffix)"
        }
        return "\(String(format: "%g", value))\(unit.suffix)"
    }
}

public struct USBTopologyNode: Identifiable, Codable, Hashable, Sendable {
    public let device: USBDevice
    public let children: [USBTopologyNode]

    public init(device: USBDevice, children: [USBTopologyNode]) {
        self.device = device
        self.children = children
    }

    public var id: UInt64 { device.id }

    public func visible(includeHubs: Bool) -> [USBTopologyNode] {
        let visibleChildren = children.flatMap { $0.visible(includeHubs: includeHubs) }
        if device.isHub && !includeHubs {
            return visibleChildren
        }
        return [USBTopologyNode(device: device, children: visibleChildren)]
    }
}

public struct USBSnapshot: Sendable {
    public let devices: [USBDevice]
    public let topology: [USBTopologyNode]
    public let serialDevices: [USBDevice]
    public let capturedAt: Date

    public init(
        devices: [USBDevice],
        topology: [USBTopologyNode],
        serialDevices: [USBDevice],
        capturedAt: Date = .now
    ) {
        self.devices = devices
        self.topology = topology
        self.serialDevices = serialDevices
        self.capturedAt = capturedAt
    }
}

public enum USBEventAction: String, Codable, Sendable {
    case present
    case add
    case remove
}

public struct USBEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let action: USBEventAction
    public let device: USBDevice
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        action: USBEventAction,
        device: USBDevice,
        timestamp: Date = .now
    ) {
        self.id = id
        self.action = action
        self.device = device
        self.timestamp = timestamp
    }
}

private extension String {
    var nonEmptyOrUnknown: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : trimmed
    }
}
