import LSUSDCore
import SwiftUI

struct DeviceInspector: View {
    @Environment(AppModel.self) private var model
    let device: USBDevice

    var body: some View {
        Form {
            Section(R.L.Details_IDENTITY) {
                LabeledContent(R.L.Details_PRODUCT) {
                    DeviceIdentityLabel(
                        product: device.product,
                        isSerial: model.isSerialDevice(device)
                    )
                }
                DetailRow(label: R.L.Details_VENDOR, value: device.vendor)
                DetailRow(label: R.L.Details_SERIAL, value: device.serial, technical: true)
                DetailRow(
                    label: R.L.Details_VENDOR_ID,
                    value: String(format: "0x%04X", device.vendorID),
                    technical: true
                )
                DetailRow(
                    label: R.L.Details_PRODUCT_ID,
                    value: String(format: "0x%04X", device.productID),
                    technical: true
                )
                DetailRow(label: R.L.Details_RELEASE, value: device.release, technical: true)
            }
            Section(R.L.Details_CONNECTION) {
                DetailRow(label: R.L.Details_BUS, value: device.busText, technical: true)
                DetailRow(label: R.L.Details_ADDRESS, value: device.addressText, technical: true)
                DetailRow(label: R.L.Details_LOCATION, value: device.locationText, technical: true)
                LabeledContent(R.L.Details_SPEED) {
                    DeviceSpeedBadge(
                        speed: device.displaySpeed,
                        bitsPerSecond: device.linkSpeed
                    )
                }
                DetailRow(label: R.L.Details_DEVICE_NODE, value: device.resolvedDeviceNode, technical: true)
                DetailRow(label: R.L.Details_HUB, value: device.isHub ? R.L.Details_YES : R.L.Details_NO)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(R.L.Details_TITLE)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var technical = false

    var body: some View {
        LabeledContent(label) {
            Text(value)
                .font(technical ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
    }
}
