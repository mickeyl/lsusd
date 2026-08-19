import Foundation
import LSUSDCore
import Observation

enum AppSection: String, CaseIterable, Identifiable {
    case devices
    case topology
    case serial
    case events

    var id: Self { self }
}

enum MenuDeviceScope: String, CaseIterable, Identifiable {
    case all
    case serial

    var id: Self { self }
}

enum DeviceSortOrder: String, CaseIterable, Identifiable {
    case alphabetical
    case speed
    case deviceType

    var id: Self { self }
}

@MainActor
@Observable
final class AppModel {
    private(set) var devices: [USBDevice] = []
    private(set) var topology: [USBTopologyNode] = []
    private(set) var serialDevices: [USBDevice] = []
    private(set) var events: [USBEvent] = []
    private(set) var lastUpdated: Date?
    private(set) var isLoading = false
    var errorMessage: String?
    var searchText = ""
    var selectedSection: AppSection = .devices
    var selectedDeviceID: USBDevice.ID?
    var menuDeviceScope: MenuDeviceScope = .all
    var showHubs: Bool {
        didSet { UserDefaults.standard.set(showHubs, forKey: Self.showHubsKey) }
    }
    var deviceSortOrder: DeviceSortOrder {
        didSet {
            UserDefaults.standard.set(deviceSortOrder.rawValue, forKey: Self.deviceSortOrderKey)
        }
    }

    @ObservationIgnored private let repository = USBRepository()
    @ObservationIgnored private var monitor: IOKitChangeMonitor?
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var refreshRequested = false
    @ObservationIgnored private var pendingRefreshRecordsEvents = false

    init() {
        showHubs = UserDefaults.standard.bool(forKey: Self.showHubsKey)
        deviceSortOrder = UserDefaults.standard.string(forKey: Self.deviceSortOrderKey)
            .flatMap(DeviceSortOrder.init(rawValue:)) ?? .alphabetical
    }

    var visibleDevices: [USBDevice] {
        visibleDevices(from: devices)
    }

    var visibleSerialDevices: [USBDevice] {
        visibleSerialDevices(from: serialDevices)
    }

    var visibleTopology: [USBTopologyNode] {
        topology.flatMap { $0.visible(includeHubs: showHubs) }
    }

    var selectedDevice: USBDevice? {
        let all = devices + serialDevices
        return all.first { $0.id == selectedDeviceID }
    }

    func isSerialDevice(_ device: USBDevice) -> Bool {
        isSerialDevice(device, among: serialDevices)
    }

    func isSerialDevice(_ device: USBDevice, among candidates: [USBDevice]) -> Bool {
        if device.deviceNode != nil { return true }

        return candidates.contains { serialDevice in
            if let locationID = device.locationID,
               serialDevice.locationID == locationID {
                return true
            }
            if device.serial != "?",
               device.serial == serialDevice.serial,
               device.vendorID == serialDevice.vendorID,
               device.productID == serialDevice.productID {
                return true
            }
            return device.bus == serialDevice.bus
                && device.address == serialDevice.address
                && device.vendorID == serialDevice.vendorID
                && device.productID == serialDevice.productID
        }
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        monitor = IOKitChangeMonitor { [weak self] in
            Task { await self?.refresh(recordEvents: true) }
        }
        await refresh(recordEvents: false)
    }

    func refresh(recordEvents: Bool = false) async {
        guard !isLoading else {
            refreshRequested = true
            pendingRefreshRecordsEvents = pendingRefreshRecordsEvents || recordEvents
            return
        }
        isLoading = true
        defer { isLoading = false }

        var shouldRecordEvents = recordEvents
        repeat {
            refreshRequested = false
            pendingRefreshRecordsEvents = false

            do {
                let snapshot = try await repository.snapshot()
                if shouldRecordEvents {
                    appendDiff(from: serialDevices, to: snapshot.serialDevices)
                } else if events.isEmpty {
                    events = snapshot.serialDevices.map {
                        USBEvent(action: .present, device: $0, timestamp: snapshot.capturedAt)
                    }
                }
                devices = snapshot.devices
                topology = snapshot.topology
                serialDevices = snapshot.serialDevices
                lastUpdated = snapshot.capturedAt
                errorMessage = nil

                if let selectedDeviceID,
                   !devices.contains(where: { $0.id == selectedDeviceID }),
                   !serialDevices.contains(where: { $0.id == selectedDeviceID }) {
                    self.selectedDeviceID = nil
                }
            } catch {
                errorMessage = error.localizedDescription
            }

            shouldRecordEvents = pendingRefreshRecordsEvents
        } while refreshRequested
    }

    func visibleDevices(
        from source: [USBDevice],
        serialCandidates: [USBDevice]? = nil
    ) -> [USBDevice] {
        sorted(
            source.filter { (showHubs || !$0.isHub) && matchesSearch($0) },
            serialCandidates: serialCandidates
        )
    }

    func visibleSerialDevices(from source: [USBDevice]) -> [USBDevice] {
        sorted(source.filter(matchesSearch), serialCandidates: source)
    }

    func clearEvents() {
        events.removeAll()
    }

    private func appendDiff(from previous: [USBDevice], to current: [USBDevice]) {
        let old = Dictionary(uniqueKeysWithValues: previous.map { ($0.resolvedDeviceNode, $0) })
        let new = Dictionary(uniqueKeysWithValues: current.map { ($0.resolvedDeviceNode, $0) })
        let additions = new.keys.filter { old[$0] == nil }.sorted().compactMap { new[$0] }
        let removals = old.keys.filter { new[$0] == nil }.sorted().compactMap { old[$0] }
        let now = Date.now
        let changes = additions.map { USBEvent(action: .add, device: $0, timestamp: now) }
            + removals.map { USBEvent(action: .remove, device: $0, timestamp: now) }
        events.insert(contentsOf: changes.reversed(), at: 0)
        if events.count > 250 { events.removeLast(events.count - 250) }
    }

    private func matchesSearch(_ device: USBDevice) -> Bool {
        guard !searchText.isEmpty else { return true }
        let needle = searchText.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return [
            device.product, device.vendor, device.serial, device.vidpid,
            device.locationText, device.resolvedDeviceNode
        ].contains { value in
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(needle)
        }
    }

    private func sorted(
        _ devices: [USBDevice],
        serialCandidates: [USBDevice]? = nil
    ) -> [USBDevice] {
        devices.sorted { lhs, rhs in
            switch deviceSortOrder {
            case .alphabetical:
                return alphabeticallyPrecedes(lhs, rhs)
            case .speed:
                if lhs.linkSpeed != rhs.linkSpeed {
                    return (lhs.linkSpeed ?? 0) > (rhs.linkSpeed ?? 0)
                }
                return alphabeticallyPrecedes(lhs, rhs)
            case .deviceType:
                let candidates = serialCandidates ?? serialDevices
                let lhsType = deviceTypeSortRank(lhs, serialCandidates: candidates)
                let rhsType = deviceTypeSortRank(rhs, serialCandidates: candidates)
                if lhsType != rhsType { return lhsType < rhsType }
                return alphabeticallyPrecedes(lhs, rhs)
            }
        }
    }

    private func alphabeticallyPrecedes(_ lhs: USBDevice, _ rhs: USBDevice) -> Bool {
        for (left, right) in zip(
            [lhs.product, lhs.vendor, lhs.vidpid],
            [rhs.product, rhs.vendor, rhs.vidpid]
        ) {
            switch left.localizedStandardCompare(right) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: continue
            }
        }
        return lhs.id < rhs.id
    }

    private func deviceTypeSortRank(
        _ device: USBDevice,
        serialCandidates: [USBDevice]
    ) -> UInt16 {
        if isSerialDevice(device, among: serialCandidates) { return 0 }
        if device.isHub { return 1 }
        guard let deviceClass = device.deviceClass, deviceClass != 0 else {
            return UInt16.max
        }
        return UInt16(deviceClass) + 1
    }

    private static let showHubsKey = "showUSBHubs"
    private static let deviceSortOrderKey = "deviceSortOrder"
}
