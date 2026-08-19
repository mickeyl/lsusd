import SwiftUI

@main
struct LSUSDApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window(R.L.App_DEVICES_WINDOW, id: "devices") {
            MainWindowView()
                .environment(model)
        }
        .defaultSize(width: 1_100, height: 680)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)
        .commands {
            CommandGroup(replacing: .newItem) {
                OpenWindowButton()
            }
            CommandGroup(after: .toolbar) {
                Button(R.L.Common_REFRESH) {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r")
            }
        }

        MenuBarExtra {
            MenuBarPanel()
                .environment(model)
        } label: {
            MenuBarLabel(
                deviceCount: model.lastUpdated == nil ? nil : model.visibleDevices.count,
                serialDeviceCount: model.lastUpdated == nil ? nil : model.visibleSerialDevices.count
            )
            .task { await model.start() }
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    let deviceCount: Int?
    let serialDeviceCount: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            Image(systemName: "cable.connector")
            if let deviceCount, let serialDeviceCount {
                Text(verbatim: "\(deviceCount)\u{00b7}\(serialDeviceCount)")
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .padding(.top, Metrics.countTopPadding)
            }
        }
        .font(.body)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let deviceCount, let serialDeviceCount else { return R.L.App_NAME }
        return R.L.MenuBar_COUNT_ACCESSIBILITY(
            LocalizedDeviceCount.usb(deviceCount),
            LocalizedDeviceCount.serial(serialDeviceCount)
        )
    }

    private enum Metrics {
        static let countTopPadding: CGFloat = 6
    }
}

private struct OpenWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(R.L.Common_OPEN_WINDOW) {
            openWindow(id: "devices")
        }
        .keyboardShortcut("1")
    }
}
