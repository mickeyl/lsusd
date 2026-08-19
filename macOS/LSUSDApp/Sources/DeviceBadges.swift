import SwiftUI

enum LSUSDLayoutMetric {
    static let menuScrollContentTrailing: CGFloat = 12
    static let badgeHorizontalPadding: CGFloat = 7
    static let badgeVerticalPadding: CGFloat = 3
    static let identitySpacing: CGFloat = 6
    static let speedBadgeFillOpacity = 0.20
    static let speedBadgeStrokeOpacity = 0.45
    static let speedBadgeStrokeWidth: CGFloat = 0.5
}

struct DeviceIdentityLabel: View {
    let product: String
    let isSerial: Bool

    var body: some View {
        HStack(spacing: LSUSDLayoutMetric.identitySpacing) {
            Text(verbatim: product)
                .lineLimit(1)

            if isSerial {
                SerialDeviceBadge()
            }
        }
    }
}

struct SerialDeviceBadge: View {
    var body: some View {
        Image(systemName: "terminal")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, LSUSDLayoutMetric.badgeHorizontalPadding - 2)
            .padding(.vertical, LSUSDLayoutMetric.badgeVerticalPadding)
            .background(.quaternary, in: Capsule())
            .accessibilityLabel(R.L.Badge_SERIAL_DEVICE)
            .help(R.L.Badge_SERIAL_DEVICE)
    }
}

struct DeviceSpeedBadge: View {
    let speed: String
    let bitsPerSecond: UInt64?

    private var tier: DeviceSpeedTier {
        DeviceSpeedTier(bitsPerSecond: bitsPerSecond)
    }

    var body: some View {
        Text(verbatim: speed)
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, LSUSDLayoutMetric.badgeHorizontalPadding)
            .padding(.vertical, LSUSDLayoutMetric.badgeVerticalPadding)
            .background(tier.tint.opacity(LSUSDLayoutMetric.speedBadgeFillOpacity), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        tier.tint.opacity(LSUSDLayoutMetric.speedBadgeStrokeOpacity),
                        lineWidth: LSUSDLayoutMetric.speedBadgeStrokeWidth
                    )
            }
    }
}

private enum DeviceSpeedTier {
    case slow
    case medium
    case fast
    case ultra

    init(bitsPerSecond: UInt64?) {
        guard let bitsPerSecond else {
            self = .slow
            return
        }

        switch bitsPerSecond {
        case ...12_000_000:
            self = .slow
        case ...480_000_000:
            self = .medium
        case ..<10_000_000_000:
            self = .fast
        default:
            self = .ultra
        }
    }

    var tint: Color {
        switch self {
        case .slow: .gray
        case .medium: .blue
        case .fast: .orange
        case .ultra: .purple
        }
    }
}
