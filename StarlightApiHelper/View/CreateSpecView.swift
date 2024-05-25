import SwiftUI
import SwiftyJSON
import SwiftApiAdapter

struct CreateSpecView: View {
    @State private var selectedJsonString: String = ""
    @State private var selectedJsonName: String = ""
    @State private var descriptionForSelectedJson: String = ""
    @State private var placeholders: [(key: String, value: String)] = []

    @State private var isPresentedJsonDocumentImporter = false
    @State private var isPresentedJsonDocumentImporterAlert = false
    @State private var jsonDocumentImportErrorMessage: String = ""

    @State private var exportingJsonData: Data = Data()
    @State private var isPresentedJsonDocumentExporter: Bool = false

    private var fileNames: [String] {
        Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Presets/Text2Text")?
            .map { $0.lastPathComponent } ?? []
    }

    var body: some View {
        Form {
            Section(
                header: Text("Select an API Spec template")
            ) {
                Button(action: {
                    isPresentedJsonDocumentImporter = true
                }) {
                    Label("Load", systemImage: "square.and.arrow.down")
                }
                .padding(.bottom, 10)
            }

            Section(
                header: Text("Selected template")
            ) {
                ScrollView {
                    Text(formatJsonStringForDisplay(selectedJsonString))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .frame(height: 250)
                .border(Color.gray, width: 1)
                .padding(.horizontal)
                .padding(.bottom, 10)

                if !descriptionForSelectedJson.isEmpty {
                    Text(descriptionForSelectedJson)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                        .foregroundColor(.secondary)
                }
            }

            Section(
                header: Text("User settings")
            ) {
                Group {
                    if placeholders.count > 0 {
                        Grid {
                            ForEach($placeholders, id: \.key) { $placeholder in
                                GridRow {
                                    Text("\(placeholder.key)")
                                        .padding(.leading)
                                    TextEditor(text: $placeholder.value)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .frame(height: 60)
                                        .padding(.trailing)
                                }
                            }
                        }
                    } else {
                        Text("No user settings found.")
                            .padding(.leading, 10)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 10)
            }

            Divider()

            Button("💾 Save API Spec") {
                saveApiSpec()
            }
            .disabled(!isAllPlaceholdersFilled)
            .listRowBackground(Color(.clear))
            .listRowSeparator(.hidden)

            Spacer()
        }
        .fileExporter(
            isPresented: $isPresentedJsonDocumentExporter,
            document: JsonDocument(data: exportingJsonData),
            contentType: .json,
            defaultFilename: selectedJsonName
        ) { result in
            switch result {
            case .success:
                print("Export successful.")
            case .failure(let error):
                print("Error exporting file: \(error)")
            }
        }
        .fileImporter(
            isPresented: $isPresentedJsonDocumentImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                #if DEBUG
                print("imported urls: \(urls)")
                #endif
                if let firstURL = urls.first {
                    if firstURL.startAccessingSecurityScopedResource() {
                        if let string = JSONManager().importJsonFromLocalFile(url: firstURL) {
                            selectedJsonString = string
                            if let data = string.data(using: .utf8) {
                                do {
                                    var json = try JSONSerialization.jsonObject(with: data, options: [])
                                    json = formatFloatingPointsInJson(json)
                                    let formattedData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                                    if let formattedString = String(data: formattedData, encoding: .utf8) {
                                        //print("JSON String:\n\(formattedString)")
                                        selectedJsonString = formattedString
                                    } else {
                                        print("failed to convert formattedData to string")
                                    }
                                } catch(let error) {
                                    print("failed to parse selectedJsonString: \(error)")
                                }
                            } else {
                                print("failed to convert selectedJsonString to data")
                            }
                            updatePlaceholdersAndDescription()
                            isPresentedJsonDocumentImporter = false
                        } else {
                            #if DEBUG
                            print("failed to load JSON")
                            #endif
                            jsonDocumentImportErrorMessage = "Invalid data format"
                            isPresentedJsonDocumentImporterAlert = true
                            isPresentedJsonDocumentImporter = false
                        }
                    } else {
                        #if DEBUG
                        print("failed to enter security scope of imported JSON file")
                        #endif
                        jsonDocumentImportErrorMessage = "Security Error"
                        isPresentedJsonDocumentImporterAlert = true
                        isPresentedJsonDocumentImporter = false
                    }
                    firstURL.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                print("Error importing file: \(error)")
                jsonDocumentImportErrorMessage = "Unexpected Error"
                isPresentedJsonDocumentImporterAlert = true
            }
        }
        .alert(isPresented: $isPresentedJsonDocumentImporterAlert) {
            Alert(title: Text("Import Error"),
                  message: Text("Failed to import JSON file. (\(jsonDocumentImportErrorMessage))"),
                  dismissButton: .default(Text("OK")))
        }
        .padding()
        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 800, maxHeight: .infinity)
    }

    private var isAllPlaceholdersFilled: Bool {
        placeholders.allSatisfy { !$0.value.isEmpty }
    }

    private func updatePlaceholdersAndDescription() {
        placeholders = []
        do {
            if let data = selectedJsonString.data(using: .utf8) {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                detectPlaceholdersInJson(json, pattern: "\\$[a-zA-Z0-9_]+", detectedPlaceholders: &placeholders)
                if let castedJsonObject = json as? [String: Any] {
                    descriptionForSelectedJson = castedJsonObject["description"] as? String ?? ""
                }
            }
        } catch {
            print("failed to parse selectedJsonString")
        }
    }

    private func saveApiSpec() {
        Task {
            do {
                guard let data = selectedJsonString.data(using: .utf8) else {
                    return
                }
                var jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                jsonObject = formatFloatingPointsInJson(jsonObject)
                for placeholder in placeholders {
                    replacePlaceholdersInJson(&jsonObject, placeholder: placeholder.key, userValue: placeholder.value)
                }
                if let castedJsonObject = jsonObject as? [String: Any] {
                    selectedJsonName = castedJsonObject["name"] as? String ?? ""
                }
                let modifiedJson = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
                exportingJsonData = modifiedJson
                isPresentedJsonDocumentExporter = true
            } catch {
                print("Failed to process API content: \(error)")
            }
        }
    }
}

#Preview {
    CreateSpecView()
}
