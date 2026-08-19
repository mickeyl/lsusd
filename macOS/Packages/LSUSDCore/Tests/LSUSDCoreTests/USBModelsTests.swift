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

    @Test func exportsCLICompatibleCSV() throws {
        let data = try USBExport.data(devices: [sampleDevice()], serialOnly: false, format: .csv)
        let text = try #require(String(data: data, encoding: .utf8))

        #expect(text.hasPrefix("bus,address,location,product,vendor,serial,vidpid,release,speed\n"))
        #expect(text.contains("001,002,0x01400000,Product,Vendor,SERIAL,1234:00AB,1.00,480M"))
    }

    @Test func hidesHubsWithoutDroppingTheirChildren() {
        let leaf = USBTopologyNode(device: sampleDevice(id: 2), children: [])
        let hub = USBTopologyNode(device: sampleDevice(id: 1, hub: true), children: [leaf])

        #expect(hub.visible(includeHubs: false).map(\.id) == [2])
        #expect(hub.visible(includeHubs: true).map(\.id) == [1])
    }

    @Test func exportsWatchCompatibleEvents() throws {
        let event = USBEvent(action: .add, device: sampleDevice())
        let data = try USBExport.data(events: [event], format: .csv)
        let text = try #require(String(data: data, encoding: .utf8))

        #expect(text.hasPrefix("action,device,product,vendor,serial,vidpid,release\n"))
        #expect(text.contains("add,/dev/bus/usb/001/002,Product,Vendor,SERIAL,1234:00AB,1.00"))
    }

    @Test func displayCycleRetainsRemovedDevicesAndMarksAdditions() {
        let original = sampleDevice(id: 1)
        let added = sampleDevice(id: 2)
        var cycle = USBDeviceDisplayCycle(devices: [original])

        cycle.update(with: [added])

        #expect(cycle.items == [
            USBDeviceDisplayItem(device: original, state: .removed),
            USBDeviceDisplayItem(device: added, state: .added)
        ])
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
        let original = sampleDevice(id: 1)
        var cycle = USBDeviceDisplayCycle(devices: [original])
        cycle.update(with: [])

        cycle.update(with: [original])

        #expect(cycle.items == [
            USBDeviceDisplayItem(device: original, state: .unchanged)
        ])
    }

    private func sampleDevice(
        id: UInt64 = 1,
        release: UInt16? = 0x0100,
        speed: UInt64? = 480_000_000,
        hub: Bool = false
    ) -> USBDevice {
        USBDevice(
            id: id,
            bus: 1,
            address: 2,
            locationID: 0x01400000,
            product: "Product",
            vendor: "Vendor",
            serial: "SERIAL",
            vendorID: 0x1234,
            productID: 0x00ab,
            releaseValue: release,
            linkSpeed: speed,
            isHub: hub,
            deviceClass: hub ? 9 : 3
        )
    }
}
