import Foundation

public enum USBExportFormat: String, CaseIterable, Identifiable, Sendable {
    case json
    case csv
    case tsv

    public var id: Self { self }
    public var filenameExtension: String { rawValue }
}

public enum USBExport {
    public static func data(
        devices: [USBDevice],
        serialOnly: Bool,
        format: USBExportFormat
    ) throws -> Data {
        let fields = serialOnly ? serialFields : deviceFields
        let rows = devices.map { device in
            fields.map { field in field.value(device) }
        }

        switch format {
        case .json:
            let objects = rows.map { row in
                Dictionary(uniqueKeysWithValues: zip(fields.map(\.name), row))
            }
            let encoder = JSONSerialization.WritingOptions([.prettyPrinted, .sortedKeys])
            let data = try JSONSerialization.data(withJSONObject: objects, options: encoder)
            return data + Data("\n".utf8)
        case .csv:
            return delimited(fields: fields, rows: rows, separator: ",", quoteCSV: true)
        case .tsv:
            return delimited(fields: fields, rows: rows, separator: "\t", quoteCSV: false)
        }
    }

    public static func data(events: [USBEvent], format: USBExportFormat) throws -> Data {
        let fields = ["action", "device", "product", "vendor", "serial", "vidpid", "release"]
        let rows = events.map { event in
            [
                event.action.rawValue,
                event.device.resolvedDeviceNode,
                event.device.product,
                event.device.vendor,
                event.device.serial,
                event.device.vidpid,
                event.device.release
            ]
        }

        switch format {
        case .json:
            let objects = rows.map { row in
                Dictionary(uniqueKeysWithValues: zip(fields, row))
            }
            let data = try JSONSerialization.data(
                withJSONObject: objects,
                options: [.prettyPrinted, .sortedKeys]
            )
            return data + Data("\n".utf8)
        case .csv:
            return delimited(fieldNames: fields, rows: rows, separator: ",", quoteCSV: true)
        case .tsv:
            return delimited(fieldNames: fields, rows: rows, separator: "\t", quoteCSV: false)
        }
    }

    private struct Field: Sendable {
        let name: String
        let value: @Sendable (USBDevice) -> String
    }

    private static let deviceFields: [Field] = [
        Field(name: "bus", value: { $0.busText }),
        Field(name: "address", value: { $0.addressText }),
        Field(name: "location", value: { $0.locationText }),
        Field(name: "product", value: { $0.product }),
        Field(name: "vendor", value: { $0.vendor }),
        Field(name: "serial", value: { $0.serial }),
        Field(name: "vidpid", value: { $0.vidpid }),
        Field(name: "release", value: { $0.release }),
        Field(name: "speed", value: { $0.speed })
    ]

    private static let serialFields: [Field] = [
        Field(name: "device", value: { $0.resolvedDeviceNode }),
        Field(name: "product", value: { $0.product }),
        Field(name: "vendor", value: { $0.vendor }),
        Field(name: "serial", value: { $0.serial }),
        Field(name: "vidpid", value: { $0.vidpid }),
        Field(name: "release", value: { $0.release })
    ]

    private static func delimited(
        fields: [Field],
        rows: [[String]],
        separator: Character,
        quoteCSV: Bool
    ) -> Data {
        delimited(
            fieldNames: fields.map(\.name),
            rows: rows,
            separator: separator,
            quoteCSV: quoteCSV
        )
    }

    private static func delimited(
        fieldNames: [String],
        rows: [[String]],
        separator: Character,
        quoteCSV: Bool
    ) -> Data {
        let lines = [fieldNames] + rows
        let text = lines.map { row in
            row.map { value in
                quoteCSV ? csvEscaped(value) : value.replacingOccurrences(of: "\t", with: " ")
            }.joined(separator: String(separator))
        }.joined(separator: "\n") + "\n"
        return Data(text.utf8)
    }

    private static func csvEscaped(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
