import Foundation
import Testing
@testable import LSUSDCore

struct USBModelsTests {
    @Test func formatsUSBDescriptorValues() {
        let device = sampleDevice(release: 0x0060, speed: 10_000_000_000)

        #expect(device.busText == "001")
        #expect(device.addressText == "002")
        #expect(device.locationText == "0x01400000")
        #expect(device.vidpid == "1234:00AB")
        #expect(device.release == "0.60")
        #expect(device.speed == "10G")
        #expect(device.deviceClass == 3)
    }

    @Test func preservesTwoBCDGroups() {
        #expect(sampleDevice(release: 0x0100).release == "1.00")
        #expect(sampleDevice(release: 0x1234).release == "12.34")
    }

    @Test func associatesAllSerialNodesWithTheirPhysicalUSBDevice() {
        let device = sampleDevice()
        let topology = [USBTopologyNode(device: device, children: [])]
        let serialPorts = [
            sampleDevice(id: 10, deviceNode: "/dev/cu.usbmodem2", isSerialPort: true),
            sampleDevice(id: 11, deviceNode: "/dev/cu.usbmodem1", isSerialPort: true),
            sampleDevice(id: 12, locationID: 0x01500000, deviceNode: "/dev/cu.other", isSerialPort: true)
        ]

        let enriched = USBTopologyNode.attachingDeviceNodes(to: topology, from: serialPorts)

        #expect(enriched[0].device.resolvedDeviceNode == "/dev/cu.usbmodem1, /dev/cu.usbmodem2")
        #expect(enriched[0].device.deviceNodes == ["/dev/cu.usbmodem1", "/dev/cu.usbmodem2"])
        #expect(!enriched[0].device.isSerialPort)
        #expect(device.resolvedDeviceNode == "?")
        #expect(serialPorts[0].resolvedDeviceNode == "/dev/cu.usbmodem2")
    }

    @Test func exportsCLICompatibleCSV() throws {
        let device = sampleDevice(deviceNode: "/dev/cu.usbmodem1, /dev/cu.usbmodem2")
        let data = try USBExport.data(devices: [device], serialOnly: false, format: .csv)
        let text = try #require(String(data: data, encoding: .utf8))

        #expect(text.hasPrefix("bus,address,device,product,vendor,serial,vidpid,release,speed\n"))
        #expect(text.contains("001,002,\"/dev/cu.usbmodem1, /dev/cu.usbmodem2\",Product,Vendor,SERIAL,1234:00AB,1.00,480M"))
    }

    @Test func exportsUnknownDeviceNodeWithoutInventingAPath() throws {
        let data = try USBExport.data(devices: [sampleDevice()], serialOnly: false, format: .json)
        let text = try #require(String(data: data, encoding: .utf8))

        #expect(text.contains("\"device\" : \"?\""))
        #expect(!text.contains("/dev/bus/usb"))
        #expect(!text.contains("location"))
    }

    @Test func hidesHubsWithoutDroppingTheirChildren() {
        let leaf = USBTopologyNode(device: sampleDevice(id: 2), children: [])
        let hub = USBTopologyNode(device: sampleDevice(id: 1, hub: true), children: [leaf])

        #expect(hub.visible(includeHubs: false).map(\.id) == [2])
        #expect(hub.visible(includeHubs: true).map(\.id) == [1])
    }

    @Test func exportsWatchCompatibleEvents() throws {
        let event = USBEvent(
            action: .add,
            device: sampleDevice(deviceNode: "/dev/cu.usbmodem1", isSerialPort: true)
        )
        let data = try USBExport.data(events: [event], format: .csv)
        let text = try #require(String(data: data, encoding: .utf8))

        #expect(text.hasPrefix("action,device,product,vendor,serial,vidpid,release\n"))
        #expect(text.contains("add,/dev/cu.usbmodem1,Product,Vendor,SERIAL,1234:00AB,1.00"))
    }

    @Test func displayCycleRetainsRemovedDevicesAndMarksAdditions() {
        let original = sampleDevice(id: 1)
        let added = sampleDevice(id: 2, locationID: 0x01300000)
        var cycle = USBDeviceDisplayCycle(devices: [original])

        cycle.update(with: [added])

        #expect(cycle.items == [
            USBDeviceDisplayItem(device: original, state: .removed),
            USBDeviceDisplayItem(device: added, state: .added)
        ])
    }

    @Test func displayCycleKeepsPhysicalDeviceWhenSerialNodeAppears() {
        var cycle = USBDeviceDisplayCycle(devices: [sampleDevice()])

        cycle.update(with: [sampleDevice(deviceNode: "/dev/cu.usbmodem1")])

        #expect(cycle.items.count == 1)
        #expect(cycle.items[0].state == .unchanged)
        #expect(cycle.items[0].device.resolvedDeviceNode == "/dev/cu.usbmodem1")
    }

    @Test func displayCycleResetClearsTransientStates() {
        let added = sampleDevice(id: 2)
        var cycle = USBDeviceDisplayCycle(devices: [sampleDevice(id: 1)])
        cycle.update(with: [added])

        cycle.reset(to: [added])

        #expect(cycle.items == [
            USBDeviceDisplayItem(device: added, state: .unchanged)
        ])
    }

    @Test func displayCycleRestoresBaselineDeviceWithoutBadge() {
        let original = sampleDevice(id: 1, serial: "?")
        var cycle = USBDeviceDisplayCycle(devices: [original])
        cycle.update(with: [])

        let reconnected = sampleDevice(id: 2, serial: "?")
        cycle.update(with: [reconnected])

        #expect(cycle.items == [
            USBDeviceDisplayItem(id: original.id, device: reconnected, state: .unchanged)
        ])
    }

    @Test func displayCycleKeepsReconnectedAdditionInSingleRow() {
        let added = sampleDevice(id: 2)
        var cycle = USBDeviceDisplayCycle(devices: [sampleDevice(id: 1, locationID: 0x01300000)])
        cycle.update(with: [added])
        cycle.update(with: [])

        let reconnected = sampleDevice(id: 3)
        cycle.update(with: [reconnected])

        #expect(cycle.items == [
            USBDeviceDisplayItem(
                device: sampleDevice(id: 1, locationID: 0x01300000),
                state: .removed
            ),
            USBDeviceDisplayItem(id: added.id, device: reconnected, state: .added)
        ])
    }

    @Test func displayCycleDoesNotMergeAmbiguousSerialNumbers() {
        let first = sampleDevice(id: 1, locationID: 0x01300000)
        let second = sampleDevice(id: 2, locationID: 0x01400000)
        var cycle = USBDeviceDisplayCycle(devices: [first, second])
        cycle.update(with: [])

        let reconnectedFirst = sampleDevice(id: 3, locationID: first.locationID)
        let reconnectedSecond = sampleDevice(id: 4, locationID: second.locationID)
        cycle.update(with: [reconnectedFirst, reconnectedSecond])

        #expect(cycle.items == [
            USBDeviceDisplayItem(id: first.id, device: reconnectedFirst, state: .unchanged),
            USBDeviceDisplayItem(id: second.id, device: reconnectedSecond, state: .unchanged)
        ])
    }

    private func sampleDevice(
        id: UInt64 = 1,
        release: UInt16? = 0x0100,
        speed: UInt64? = 480_000_000,
        hub: Bool = false,
        locationID: UInt32? = 0x01400000,
        serial: String = "SERIAL",
        deviceNode: String? = nil,
        isSerialPort: Bool = false
    ) -> USBDevice {
        USBDevice(
            id: id,
            bus: 1,
            address: 2,
            locationID: locationID,
            product: "Product",
            vendor: "Vendor",
            serial: serial,
            vendorID: 0x1234,
            productID: 0x00ab,
            releaseValue: release,
            linkSpeed: speed,
            isHub: hub,
            deviceClass: hub ? 9 : 3,
            deviceNode: deviceNode,
            isSerialPort: isSerialPort
        )
    }
}
