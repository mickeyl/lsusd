import AppKit
import LSUSDCore
import SwiftUI

extension View {
    func copySerialPortContextMenu(for device: USBDevice) -> some View {
        modifier(SerialPortCopyContextMenu(paths: device.deviceNodes))
    }
}

private struct SerialPortCopyContextMenu: ViewModifier {
    let paths: [String]

    @ViewBuilder
    func body(content: Content) -> some View {
        if paths.isEmpty {
            content
        } else {
            content.contextMenu(menuItems: {
                ForEach(paths, id: \.self) { path in
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path, forType: .string)
                    } label: {
                        Label(R.L.Common_COPY_DEVICE_NODE(path), systemImage: "doc.on.doc")
                    }
                }
            })
        }
    }
}
