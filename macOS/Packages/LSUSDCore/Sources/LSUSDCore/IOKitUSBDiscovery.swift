import Foundation
import IOKit

public actor USBRepository {
    public init() {}

    public func snapshot() throws -> USBSnapshot {
        let discovery = IOKitUSBDiscovery()
        let topology = try discovery.discoverTopology()
        let devices = topology.flatMap(\.flattenedDevices)
            .sorted(by: USBDevice.registryOrder)
        let serialDevices = try discovery.discoverSerialDevices(usbDevices: devices)
        return USBSnapshot(
            devices: devices,
            topology: topology,
            serialDevices: serialDevices
        )
    }
}

public struct USBDiscoveryError: LocalizedError, Sendable {
    public let operation: String
    public let code: kern_return_t

    public var errorDescription: String? {
        "\(operation) failed (IOKit error \(code))."
    }
}

private struct IOKitUSBDiscovery {
    func discoverTopology() throws -> [USBTopologyNode] {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        return try childNodes(of: root)
    }

    func discoverSerialDevices(usbDevices: [USBDevice]) throws -> [USBDevice] {
        guard let matching = IOServiceMatching("IOSerialBSDClient") else { return [] }
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else {
            throw USBDiscoveryError(operation: "IOServiceGetMatchingServices", code: result)
        }
        defer { IOObjectRelease(iterator) }

        var resultDevices: [USBDevice] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let node = stringProperty("IOCalloutDevice", of: service),
                  node.hasPrefix("/dev/cu.usb") else { continue }

            let serviceID = registryID(of: service)
            let ancestor = usbAncestorProperties(of: service)
            let vendorID = uint16(ancestor["idVendor"])
            let productID = uint16(ancestor["idProduct"])
            let serial = firstString(in: ancestor, keys: ["USB Serial Number", "kUSBSerialNumberString"])
            let matched = usbDevices.first(where: {
                serial != "?" && $0.serial == serial
            }) ?? usbDevices.uniqueMatch(vendorID: vendorID, productID: productID)

            resultDevices.append(USBDevice(
                id: serviceID,
                bus: matched?.bus ?? bus(from: uint32(ancestor["locationID"])),
                address: matched?.address ?? int(ancestor["USB Address"]),
                locationID: matched?.locationID ?? optionalUInt32(ancestor["locationID"]),
                product: matched?.product ?? firstString(in: ancestor, keys: ["kUSBProductString", "USB Product Name"]),
                vendor: matched?.vendor ?? firstString(in: ancestor, keys: ["kUSBVendorString", "USB Vendor Name"]),
                serial: matched?.serial ?? serial,
                vendorID: matched?.vendorID ?? vendorID,
                productID: matched?.productID ?? productID,
                releaseValue: matched?.releaseValue ?? optionalUInt16(ancestor["bcdDevice"]),
                linkSpeed: matched?.linkSpeed ?? optionalUInt64(ancestor["UsbLinkSpeed"]),
                isHub: false,
                deviceClass: matched?.deviceClass ?? optionalUInt8(ancestor["bDeviceClass"]),
                deviceNode: node
            ))
        }
        return resultDevices.sorted { $0.resolvedDeviceNode < $1.resolvedDeviceNode }
    }

    private func childNodes(of entry: io_registry_entry_t) throws -> [USBTopologyNode] {
        var iterator: io_iterator_t = 0
        let result = "IOUSB".withCString {
            IORegistryEntryGetChildIterator(entry, $0, &iterator)
        }
        guard result == KERN_SUCCESS else {
            throw USBDiscoveryError(operation: "IORegistryEntryGetChildIterator", code: result)
        }
        defer { IOObjectRelease(iterator) }

        var nodes: [USBTopologyNode] = []
        while case let child = IOIteratorNext(iterator), child != 0 {
            defer { IOObjectRelease(child) }
            let childNodes = try childNodes(of: child)
            if let device = usbDevice(from: child) {
                nodes.append(USBTopologyNode(device: device, children: childNodes))
            } else {
                nodes.append(contentsOf: childNodes)
            }
        }
        return nodes.sorted { USBDevice.registryOrder($0.device, $1.device) }
    }

    private func usbDevice(from entry: io_registry_entry_t) -> USBDevice? {
        let properties = allProperties(of: entry)
        guard properties["idVendor"] != nil, properties["idProduct"] != nil else {
            return nil
        }
        let locationID = optionalUInt32(properties["locationID"])
        let deviceClass = optionalUInt8(properties["bDeviceClass"])
        return USBDevice(
            id: registryID(of: entry),
            bus: bus(from: locationID ?? 0),
            address: int(properties["USB Address"]),
            locationID: locationID,
            product: firstString(
                in: properties,
                keys: ["kUSBProductString", "USB Product Name", "IORegistryEntryName"]
            ),
            vendor: firstString(in: properties, keys: ["kUSBVendorString", "USB Vendor Name"]),
            serial: firstString(in: properties, keys: ["USB Serial Number", "kUSBSerialNumberString"]),
            vendorID: uint16(properties["idVendor"]),
            productID: uint16(properties["idProduct"]),
            releaseValue: optionalUInt16(properties["bcdDevice"]),
            linkSpeed: optionalUInt64(properties["UsbLinkSpeed"]),
            isHub: deviceClass == 9,
            deviceClass: deviceClass
        )
    }

    private func usbAncestorProperties(of entry: io_registry_entry_t) -> [String: Any] {
        var merged: [String: Any] = [:]
        var current = entry
        var ownsCurrent = false

        while current != 0 {
            let properties = allProperties(of: current)
            for (key, value) in properties where merged[key] == nil {
                merged[key] = value
            }
            var parent: io_registry_entry_t = 0
            let result = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
            if ownsCurrent { IOObjectRelease(current) }
            guard result == KERN_SUCCESS else {
                current = 0
                ownsCurrent = false
                break
            }
            current = parent
            ownsCurrent = true
        }
        return merged
    }

    private func allProperties(of entry: io_registry_entry_t) -> [String: Any] {
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dictionary = properties?.takeRetainedValue() as? [String: Any] else {
            return [:]
        }
        return dictionary
    }

    private func stringProperty(_ key: String, of entry: io_registry_entry_t) -> String? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }

    private func registryID(of entry: io_registry_entry_t) -> UInt64 {
        var id: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(entry, &id)
        return id
    }

    private func firstString(in properties: [String: Any], keys: [String]) -> String {
        for key in keys {
            if let value = properties[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return "?"
    }

    private func number(_ value: Any?) -> NSNumber? {
        if let number = value as? NSNumber { return number }
        if let data = value as? Data, !data.isEmpty {
            var result: UInt64 = 0
            for (index, byte) in data.prefix(8).enumerated() {
                result |= UInt64(byte) << UInt64(index * 8)
            }
            return NSNumber(value: result)
        }
        return nil
    }

    private func int(_ value: Any?) -> Int { number(value)?.intValue ?? 0 }
    private func uint16(_ value: Any?) -> UInt16 { number(value)?.uint16Value ?? 0 }
    private func uint32(_ value: Any?) -> UInt32 { number(value)?.uint32Value ?? 0 }
    private func optionalUInt8(_ value: Any?) -> UInt8? { number(value)?.uint8Value }
    private func optionalUInt16(_ value: Any?) -> UInt16? { number(value)?.uint16Value }
    private func optionalUInt32(_ value: Any?) -> UInt32? { number(value)?.uint32Value }
    private func optionalUInt64(_ value: Any?) -> UInt64? { number(value)?.uint64Value }
    private func bus(from locationID: UInt32) -> Int { Int((locationID >> 24) & 0xff) }
}

private extension USBTopologyNode {
    var flattenedDevices: [USBDevice] {
        [device] + children.flatMap(\.flattenedDevices)
    }
}

private extension USBDevice {
    static func registryOrder(_ lhs: USBDevice, _ rhs: USBDevice) -> Bool {
        (lhs.locationText, lhs.address, lhs.vidpid) < (rhs.locationText, rhs.address, rhs.vidpid)
    }
}

private extension Array where Element == USBDevice {
    func uniqueMatch(vendorID: UInt16, productID: UInt16) -> USBDevice? {
        let matches = filter { $0.vendorID == vendorID && $0.productID == productID }
        return matches.count == 1 ? matches[0] : nil
    }
}
