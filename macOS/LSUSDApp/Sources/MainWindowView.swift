import AppKit
import LSUSDCore
import SwiftUI
import UniformTypeIdentifiers

struct MainWindowView: View {
    @Environment(AppModel.self) private var model
    @State private var isExporting = false
    @State private var exportDocument = USBDataDocument()
    @State private var exportType: UTType = .json
    @State private var exportFilename = "lsusd.json"

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(AppSection.allCases, selection: $model.selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 230)
        } detail: {
            sectionContent
                .navigationTitle(model.selectedSection.title)
                .searchable(text: $model.searchText, prompt: R.L.Search_PROMPT)
                .toolbar { toolbar }
        }
        .frame(minWidth: 820, minHeight: 500)
        .inspector(isPresented: inspectorPresented) {
            if let device = model.selectedDevice {
                DeviceInspector(device: device)
                    .inspectorColumnWidth(min: 260, ideal: 310, max: 380)
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: exportType,
            defaultFilename: exportFilename
        ) { _ in }
        .alert(R.L.Error_TITLE, isPresented: errorPresented) {
            Button(R.L.Error_DISMISS) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch model.selectedSection {
        case .devices:
            DeviceTable(devices: model.visibleDevices, selection: selection)
        case .topology:
            TopologyView(nodes: model.visibleTopology, selection: selection)
        case .serial:
            SerialDeviceTable(devices: model.visibleSerialDevices, selection: selection)
        case .events:
            EventsView(events: model.events, selection: selection)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Toggle(isOn: showHubs) {
                Label(R.L.Common_SHOW_HUBS, systemImage: "point.3.connected.trianglepath.dotted")
            }
            .toggleStyle(.button)
            .help(R.L.Common_SHOW_HUBS)
        }

        ToolbarSpacer(.fixed)

        ToolbarItem(placement: .automatic) {
            Button {
                Task { await model.refresh() }
            } label: {
                Label(R.L.Common_REFRESH, systemImage: "arrow.clockwise")
            }
            .disabled(model.isLoading)
            .help(R.L.Common_REFRESH)
        }

        if model.selectedSection == .events {
            ToolbarItem(placement: .automatic) {
                Button {
                    model.clearEvents()
                } label: {
                    Label(R.L.Common_CLEAR, systemImage: "trash")
                }
                .disabled(model.events.isEmpty)
                .help(R.L.Common_CLEAR)
            }
        }

        ToolbarSpacer(.fixed)

        ToolbarItem(placement: .automatic) {
            Menu {
                Section(R.L.Common_COPY) {
                    exportButtons(copy: true)
                }
                Section(R.L.Common_EXPORT) {
                    exportButtons(copy: false)
                }
            } label: {
                Label(R.L.Common_EXPORT, systemImage: "square.and.arrow.up")
            }
        }
    }

    @ViewBuilder
    private func exportButtons(copy: Bool) -> some View {
        ForEach(USBExportFormat.allCases) { format in
            Button(format.title(copy: copy)) {
                copy ? copyExport(format) : beginExport(format)
            }
        }
    }

    private var exportDevices: [USBDevice] {
        model.selectedSection == .serial ? model.visibleSerialDevices : model.visibleDevices
    }

    private var exportsSerialFields: Bool { model.selectedSection == .serial }

    private func data(for format: USBExportFormat) -> Data? {
        if model.selectedSection == .events {
            return try? USBExport.data(events: model.events, format: format)
        }
        return try? USBExport.data(
            devices: exportDevices,
            serialOnly: exportsSerialFields,
            format: format
        )
    }

    private func copyExport(_ format: USBExportFormat) {
        guard let data = data(for: format), let text = String(data: data, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func beginExport(_ format: USBExportFormat) {
        guard let data = data(for: format) else { return }
        exportDocument = USBDataDocument(data: data)
        exportType = format.contentType
        exportFilename = "lsusd.\(format.filenameExtension)"
        isExporting = true
    }

    private var selection: Binding<USBDevice.ID?> {
        Binding(
            get: { model.selectedDeviceID },
            set: { model.selectedDeviceID = $0 }
        )
    }

    private var showHubs: Binding<Bool> {
        Binding(get: { model.showHubs }, set: { model.showHubs = $0 })
    }

    private var inspectorPresented: Binding<Bool> {
        Binding(
            get: { model.selectedDevice != nil },
            set: { if !$0 { model.selectedDeviceID = nil } }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}

private extension AppSection {
    var title: String {
        switch self {
        case .devices: R.L.Sidebar_DEVICES
        case .topology: R.L.Sidebar_TOPOLOGY
        case .serial: R.L.Sidebar_SERIAL
        case .events: R.L.Sidebar_EVENTS
        }
    }

    var systemImage: String {
        switch self {
        case .devices: "cable.connector"
        case .topology: "point.3.connected.trianglepath.dotted"
        case .serial: "terminal"
        case .events: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        }
    }
}

private extension USBExportFormat {
    var contentType: UTType {
        switch self {
        case .json: .json
        case .csv: .commaSeparatedText
        case .tsv: .tabSeparatedText
        }
    }

    func title(copy: Bool) -> String {
        switch (self, copy) {
        case (.json, true): R.L.Export_COPY_JSON
        case (.csv, true): R.L.Export_COPY_CSV
        case (.tsv, true): R.L.Export_COPY_TSV
        case (.json, false): R.L.Export_JSON
        case (.csv, false): R.L.Export_CSV
        case (.tsv, false): R.L.Export_TSV
        }
    }
}

private struct USBDataDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json, .commaSeparatedText, .tabSeparatedText]
    var data = Data()

    init() {}
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
