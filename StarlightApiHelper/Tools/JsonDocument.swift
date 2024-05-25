import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct JsonDocument: FileDocument {
    var data: Data

    static var readableContentTypes: [UTType] { [.json] }

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
