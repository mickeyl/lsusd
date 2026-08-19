import LSUSDCore
import SwiftUI

struct DeviceTable: View {
    @Environment(AppModel.self) private var model
    let devices: [USBDevice]
    @Binding var selection: USBDevice.ID?

    var body: some View {
        if devices.isEmpty {
            ContentUnavailableView(
                R.L.Status_NO_DEVICES,
                systemImage: "cable.connector.slash",
                description: Text(R.L.Status_NO_DEVICES_DESCRIPTION)
            )
        } else {
            Table(devices, selection: $selection) {
                TableColumn(R.L.Table_BUS) { device in technical(device.busText) }
                    .width(min: 42, ideal: 48, max: 60)
                TableColumn(R.L.Table_DEVICE) { device in technical(device.addressText) }
                    .width(min: 50, ideal: 58, max: 70)
                TableColumn(R.L.Table_PRODUCT) { device in
                    DeviceIdentityLabel(
                        product: device.product,
                        isSerial: model.isSerialDevice(device)
                    )
                }
                    .width(min: 140, ideal: 230)
                TableColumn(R.L.Table_VENDOR, value: \.vendor)
                    .width(min: 100, ideal: 160)
                TableColumn(R.L.Table_VIDPID) { device in technical(device.vidpid) }
                    .width(min: 90, ideal: 95, max: 110)
                TableColumn(R.L.Table_RELEASE) { device in technical(device.release) }
                    .width(min: 54, ideal: 62, max: 72)
                TableColumn(R.L.Table_SPEED) { device in
                    DeviceSpeedBadge(
                        speed: device.displaySpeed,
                        bitsPerSecond: device.linkSpeed
                    )
                }
                    .width(min: 78, ideal: 88, max: 110)
            }
        }
    }

    private func technical(_ value: String) -> some View {
        Text(value).font(.system(.body, design: .monospaced))
    }
}

struct SerialDeviceTable: View {
    let devices: [USBDevice]
    @Binding var selection: USBDevice.ID?

    var body: some View {
        if devices.isEmpty {
            ContentUnavailableView(
                R.L.Status_NO_SERIAL,
                systemImage: "terminal",
                description: Text(R.L.Status_NO_SERIAL_DESCRIPTION)
            )
        } else {
            Table(devices, selection: $selection) {
                TableColumn(R.L.Table_DEVICE) { device in
                    Text(device.resolvedDeviceNode).font(.system(.body, design: .monospaced))
                }
                .width(min: 175, ideal: 220)
                TableColumn(R.L.Table_PRODUCT) { device in
                    DeviceIdentityLabel(product: device.product, isSerial: true)
                }
                    .width(min: 130, ideal: 200)
                TableColumn(R.L.Table_VENDOR, value: \.vendor)
                    .width(min: 100, ideal: 150)
                TableColumn(R.L.Table_SERIAL) { device in
                    Text(device.serial).font(.system(.body, design: .monospaced))
                }
                .width(min: 100, ideal: 150)
                TableColumn(R.L.Table_VIDPID) { device in
                    Text(device.vidpid).font(.system(.body, design: .monospaced))
                }
                .width(min: 90, ideal: 95, max: 110)
                TableColumn(R.L.Table_RELEASE) { device in
                    Text(device.release).font(.system(.body, design: .monospaced))
                }
                .width(min: 54, ideal: 62, max: 72)
            }
        }
    }
}

struct TopologyView: View {
    @Environment(AppModel.self) private var model
    let nodes: [USBTopologyNode]
    @Binding var selection: USBDevice.ID?

    var body: some View {
        if nodes.isEmpty {
            ContentUnavailableView(
                R.L.Status_NO_DEVICES,
                systemImage: "point.3.connected.trianglepath.dotted",
                description: Text(R.L.Status_NO_DEVICES_DESCRIPTION)
            )
        } else {
            List(selection: $selection) {
                OutlineGroup(nodes, children: \.outlineChildren) { node in
                    HStack(spacing: 8) {
                        Image(
                            systemName: node.device.isHub
                                ? "point.3.connected.trianglepath.dotted"
                                : "cable.connector"
                        )
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            DeviceIdentityLabel(
                                product: node.device.product,
                                isSerial: model.isSerialDevice(node.device)
                            )
                            HStack(spacing: 4) {
                                technicalCaption(node.device.vidpid)
                                Text(verbatim: "·").foregroundStyle(.tertiary)
                                DeviceSpeedBadge(
                                    speed: node.device.displaySpeed,
                                    bitsPerSecond: node.device.linkSpeed
                                )
                                Text(verbatim: "·").foregroundStyle(.tertiary)
                                technicalCaption(node.device.locationText)
                            }
                        }
                    }
                    .tag(node.device.id)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func technicalCaption(_ value: String) -> some View {
        Text(verbatim: value)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
    }
}

private extension USBTopologyNode {
    var outlineChildren: [USBTopologyNode]? { children.isEmpty ? nil : children }
}
