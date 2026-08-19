import AppKit
import LSUSDCore
import SwiftUI

struct MenuBarPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @State private var showsSettings = false
    @State private var deviceCycle = USBDeviceDisplayCycle()
    @State private var serialDeviceCycle = USBDeviceDisplayCycle()
    @State private var hasCycleBaseline = false
    @State private var isCycleActive = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if showsSettings {
                    MenuBarSettingsView()
                } else {
                    deviceSummary
                }
            }
                .frame(maxHeight: .infinity, alignment: .top)
            Divider()
            actions
        }
        .frame(width: 380, height: 760)
        .onAppear(perform: beginDisplayCycle)
        .onDisappear {
            isCycleActive = false
        }
        .onChange(of: model.lastUpdated) {
            updateDisplayCycle()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "cable.connector")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(R.L.App_NAME).font(.headline)
                if model.isLoading {
                    Text(R.L.Status_LOADING)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let lastUpdated = model.lastUpdated {
                    Text(R.L.Status_LAST_UPDATED(lastUpdated.formatted(date: .omitted, time: .shortened)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                Task {
                    await model.refresh()
                    guard isCycleActive else { return }
                    beginDisplayCycle()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(model.isLoading)
            .accessibilityLabel(R.L.Common_REFRESH)
            .help(R.L.Common_REFRESH)
        }
        .padding(14)
    }

    private var deviceSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            scopeButtons

            if displayedItems.isEmpty {
                Text(emptyDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedItems) { item in
                            Button {
                                guard item.state != .removed else { return }
                                model.selectedSection = selectedWindowSection
                                model.selectedDeviceID = item.device.id
                                showDeviceWindow()
                            } label: {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        DeviceIdentityLabel(
                                            product: item.device.product,
                                            isSerial: isSerialDevice(item.device)
                                        )
                                        .strikethrough(item.state == .removed, color: .secondary)
                                        Text(deviceSubtitle(item.device))
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        DeviceSpeedBadge(
                                            speed: item.device.displaySpeed,
                                            bitsPerSecond: item.device.linkSpeed
                                        )
                                        if item.state != .unchanged {
                                            DeviceChangeBadge(state: item.state)
                                        }
                                    }
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal, 5)
                                .background(rowTint(for: item.state), in: .rect(cornerRadius: 7))
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .disabled(item.state == .removed)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .contentMargins(
                    .trailing,
                    LSUSDLayoutMetric.menuScrollContentTrailing,
                    for: .scrollContent
                )
            }
        }
        .padding(14)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                showDeviceWindow()
            } label: {
                Label(R.L.Common_OPEN_WINDOW, systemImage: "macwindow")
            }
            .buttonStyle(.borderedProminent)

            Spacer()

            Toggle(isOn: $showsSettings) {
                Label(R.L.Common_SETTINGS, systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .toggleStyle(.button)
            .accessibilityLabel(R.L.Common_SETTINGS)
            .help(R.L.Common_SETTINGS)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(R.L.Common_QUIT, systemImage: "power")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(R.L.Common_QUIT)
            .help(R.L.Common_QUIT)
        }
        .padding(14)
    }

    private func showDeviceWindow() {
        openWindow(id: "devices")
        dismiss()
        activateApp()
    }

    private func activateApp() {
        NSApplication.shared.activate()
        Task { @MainActor in
            await Task.yield()
            NSApplication.shared.activate()
        }
    }

    private var scopeButtons: some View {
        HStack(spacing: 8) {
            scopeButton(
                .all,
                title: LocalizedDeviceCount.usb(model.visibleDevices.count),
                systemImage: "cable.connector"
            )
            scopeButton(
                .serial,
                title: LocalizedDeviceCount.serial(model.visibleSerialDevices.count),
                systemImage: "terminal"
            )
        }
    }

    private func scopeButton(
        _ scope: MenuDeviceScope,
        title: String,
        systemImage: String
    ) -> some View {
        Toggle(isOn: scopeSelection(scope)) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .toggleStyle(.button)
    }

    private func scopeSelection(_ scope: MenuDeviceScope) -> Binding<Bool> {
        Binding(
            get: { model.menuDeviceScope == scope },
            set: { isSelected in
                if isSelected { model.menuDeviceScope = scope }
            }
        )
    }

    private var displayedItems: [USBDeviceDisplayItem] {
        let items: [USBDeviceDisplayItem]
        switch model.menuDeviceScope {
        case .all: items = deviceCycle.items
        case .serial: items = serialDeviceCycle.items
        }

        let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let serialCandidates = serialDeviceCycle.items.map(\.device)
        let visibleDevices: [USBDevice]
        switch model.menuDeviceScope {
        case .all:
            visibleDevices = model.visibleDevices(
                from: items.map(\.device),
                serialCandidates: serialCandidates
            )
        case .serial:
            visibleDevices = model.visibleSerialDevices(from: items.map(\.device))
        }
        return visibleDevices.compactMap { itemByID[$0.id] }
    }

    private var emptyDescription: String {
        switch model.menuDeviceScope {
        case .all: R.L.Status_NO_DEVICES_DESCRIPTION
        case .serial: R.L.Status_NO_SERIAL_DESCRIPTION
        }
    }

    private var selectedWindowSection: AppSection {
        model.menuDeviceScope == .serial ? .serial : .devices
    }

    private func deviceSubtitle(_ device: USBDevice) -> String {
        switch model.menuDeviceScope {
        case .all: "\(device.vendor) · \(device.vidpid)"
        case .serial: "\(device.resolvedDeviceNode) · \(device.vidpid)"
        }
    }

    private func beginDisplayCycle() {
        isCycleActive = true
        deviceCycle.reset(to: model.devices)
        serialDeviceCycle.reset(to: model.serialDevices)
        hasCycleBaseline = model.lastUpdated != nil
    }

    private func updateDisplayCycle() {
        guard isCycleActive else { return }
        guard hasCycleBaseline else {
            deviceCycle.reset(to: model.devices)
            serialDeviceCycle.reset(to: model.serialDevices)
            hasCycleBaseline = true
            return
        }
        deviceCycle.update(with: model.devices)
        serialDeviceCycle.update(with: model.serialDevices)
    }

    private func isSerialDevice(_ device: USBDevice) -> Bool {
        model.isSerialDevice(device, among: serialDeviceCycle.items.map(\.device))
    }

    private func rowTint(for state: USBDeviceDisplayState) -> Color {
        switch state {
        case .unchanged: .clear
        case .added: .green.opacity(0.10)
        case .removed: .red.opacity(0.07)
        }
    }
}
