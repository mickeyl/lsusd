import Foundation
import SwiftUI

struct MenuBarSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            Label(R.L.Settings_GENERAL, systemImage: "gearshape")
                .font(.headline)

            Divider()

            Toggle(R.L.Common_SHOW_HUBS, isOn: $model.showHubs)
            Text(R.L.Settings_HUBS_NOTE)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Picker(R.L.Settings_SORT_BY, selection: $model.deviceSortOrder) {
                ForEach(DeviceSortOrder.allCases) { sortOrder in
                    Text(sortOrder.title).tag(sortOrder)
                }
            }
            .pickerStyle(.menu)

            Spacer()

            Text(credits)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(14)
    }

    private var credits: AttributedString {
        (try? AttributedString(markdown: R.L.Settings_CREDITS))
            ?? AttributedString(R.L.Settings_CREDITS)
    }
}

private extension DeviceSortOrder {
    var title: String {
        switch self {
        case .alphabetical: R.L.Settings_SORT_ALPHABETICAL
        case .speed: R.L.Settings_SORT_SPEED
        case .deviceType: R.L.Settings_SORT_DEVICE_TYPE
        }
    }
}
