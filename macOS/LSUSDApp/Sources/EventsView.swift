import LSUSDCore
import SwiftUI

struct EventsView: View {
    let events: [USBEvent]
    @Binding var selection: USBDevice.ID?

    var body: some View {
        if events.isEmpty {
            ContentUnavailableView(
                R.L.Status_NO_EVENTS,
                systemImage: "clock",
                description: Text(R.L.Status_NO_EVENTS_DESCRIPTION)
            )
        } else {
            List(events) { event in
                Button {
                    selection = event.device.id
                } label: {
                    EventRow(event: event)
                }
                .buttonStyle(.plain)
                .accessibilityHint(R.L.Details_TITLE)
            }
        }
    }
}

private struct EventRow: View {
    let event: USBEvent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.symbol)
                .foregroundStyle(event.color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.title).fontWeight(.medium)
                    DeviceIdentityLabel(product: event.device.product, isSerial: true)
                }
                Text("\(event.device.resolvedDeviceNode) · \(event.device.vidpid)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(event.timestamp, style: .time)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
    }
}

private extension USBEvent {
    var title: String {
        switch action {
        case .present: R.L.Event_PRESENT
        case .add: R.L.Event_ADD
        case .remove: R.L.Event_REMOVE
        }
    }

    var symbol: String {
        switch action {
        case .present: "circle.fill"
        case .add: "plus.circle.fill"
        case .remove: "minus.circle.fill"
        }
    }

    var color: Color {
        switch action {
        case .present: .secondary
        case .add: .green
        case .remove: .red
        }
    }
}
