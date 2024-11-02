import SwiftUI
import SwiftyJSON
import SwiftApiAdapter

struct Base64ImageView: View {
    let base64String: String

    var body: some View {
        if let imageData = Data(base64Encoded: base64String),
           let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
        } else {
            Text("Unable to load image.")
        }
    }
}

struct CallSpecView: View {
    @State private var selectedFileName: String = ""
    @State private var selectedJsonString: String = ""
    @State private var descriptionForSelectedJson: String = ""
    @State private var placeholders: [(key: String, value: String)] = []

    @State private var isPresentedJsonDocumentImporter = false
    @State private var isPresentedJsonDocumentImporterAlert = false
    @State private var jsonDocumentImportErrorMessage: String = ""

    @State private var generatedText: String = ""
    @State private var base64String: String = ""
    @State private var image: Image? = nil
    @State private var finalUrl: String = ""

    var body: some View {
        Form {
            Section(
                header: Text("Select an API Spec")
            ) {
                Button(action: {
                    isPresentedJsonDocumentImporter = true
                }) {
                    Label("Load", systemImage: "square.and.arrow.down")
                }
                .padding(.bottom, 10)
            }

            Section(
                header: Text("Selected API Spec")
            ) {
                ScrollView {
                    Text(selectedJsonString)
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
                header: Text("Simulate Application Parameters")
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
                        Text("No application parameter to set found.")
                            .padding(.leading, 10)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 10)
            }

            Divider()

            Button("✨ Call API") {
                callApi()
            }
            .listRowBackground(Color(.clear))
            .listRowSeparator(.hidden)

            Divider()

            Section(
                header: Text("Result")
            ) {
                Group {
                    if (!generatedText.isEmpty) {
                        ScrollView {
                            Text(generatedText)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(height: 250)
                        .border(Color.gray, width: 1)
                        .padding(.horizontal)
                        .padding(.bottom)

                    } else if (image != nil) {
                        ScrollView {
                            if let image = image {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 300, height: 300)
                                    .border(Color.black, width: 1)
                            } else {
                                Text("No Image Available")
                                    .frame(width: 300, height: 300)
                                    .border(Color.black, width: 1)
                            }
                        }
                        .frame(height: 250)
                        .border(Color.gray, width: 1)
                        .padding(.horizontal)
                        .padding(.bottom)
                    } else {
                        Text("None.")
                            .padding(.leading, 10)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(
                header: Text("finalUrl")
            ) {
                Group {
                    if (!finalUrl.isEmpty) {
                        Text(finalUrl)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .border(Color.gray, width: 1)
                            .padding(.horizontal)
                            .padding(.bottom)
                    } else {
                        Text("None.")
                            .padding(.leading, 10)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
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

    private func updatePlaceholdersAndDescription() {
        placeholders = []
        do {
            if let data = selectedJsonString.data(using: .utf8) {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                detectPlaceholdersInJson(json, pattern: "(?<!\\\\)<([a-zA-Z0-9]+)>", detectedPlaceholders: &placeholders)
                if let castedJsonObject = json as? [String: Any] {
                    descriptionForSelectedJson = castedJsonObject["description"] as? String ?? ""
                }
            }
        } catch {
            print("failed to parse selectedJsonString")
        }
    }

    private func callApi() {
        Task {
            do {
                guard let data = selectedJsonString.data(using: .utf8) else {
                    return
                }
                var jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                for placeholder in placeholders {
                    replacePlaceholdersInJson(&jsonObject, placeholder: placeholder.key, userValue: placeholder.value)
                }

                guard let castedJsonObject = jsonObject as? [String: Any] else {
                    print("Failed to cast JSON object.")
                    return
                }
                guard let spec = castedJsonObject["spec"] as? [String: Any] else {
                    print("Failed to get spec object.")
                    return
                }

                var body = ""
                if let bodyJson = spec["body"] as? [String: Any] {
                    let modifiedBody = try JSONSerialization.data(withJSONObject: bodyJson, options: .prettyPrinted)
                    if let modifiedBodyString = String(data: modifiedBody, encoding: .utf8) {
                        #if DEBUG
                        print("Modified JSON String:\n\(modifiedBodyString)")
                        #endif
                        body = modifiedBodyString
                    }
                }

                // Create ApiContent using the JSON dictionary
                let id = UUID() // Generate new UUID
                let name = spec["name"] as? String ?? ""
                let endpoint = spec["endpoint"] as? String ?? ""
                let methodRaw = spec["method"] as? String ?? "GET"
                let method = HttpMethod(rawValue: methodRaw) ?? .get
                let headers = spec["headers"] as? [String: String] ?? [:]

                let arguments = spec["arguments"] as? [String: String] ?? [:]
                let contentTypeRaw = spec["contentType"] as? String ?? "TEXT"
                let contentType = ContentType(rawValue: contentTypeRaw) ?? .text
                let description = spec["description"] as? String

                let apiContent = ApiContent(
                    id: id,
                    name: name,
                    endpoint: endpoint,
                    method: method,
                    headers: headers,
                    body: body,
                    arguments: arguments,
                    contentType: contentType,
                    description: description
                )

                if let contentRack = try await ApiContentLoader.load(contextId: UUID(), apiContent: apiContent) {
                    //print("Loaded contentRack: \(contentRack)")
                    switch apiContent.contentType {
                    case .text:
                        //print("Text: \(contentRack.arguments["text"] ?? "")")
                        self.generatedText = contentRack.arguments["text"] ?? ""
                        self.image = nil
                    case .base64image:
                        //print("Base64 Image: \(contentRack.arguments["base64image"] ?? "")")
                        if let base64image = contentRack.arguments["base64image"], let imageData = Data(base64Encoded: base64image), let nsImage = NSImage(data: imageData) {
                            self.image = Image(nsImage: nsImage)
                            self.generatedText = ""
                        } else {
                            self.image = nil
                            self.generatedText = "Failed to load image."
                        }
                    case .urlImage:
                        // not yet supported
                        print("URL_IMAGE is not yet supported")
                        break
                    case .page:
                        print("finalUrl: \(contentRack.arguments["finalUrl"] ?? "")")
                        self.generatedText = contentRack.arguments["content"] ?? ""
                        self.image = nil
                        self.finalUrl = contentRack.arguments["finalUrl"] ?? endpoint
                    }
                    print("Success to load.")
                } else {
                    print("Failed to load.")
                }

            } catch {
                print("Failed to process API content: \(error)")
            }
        }
        ApiConnectorManager.shared.clearConnector(for: "Text2Text")
    }
}

#Preview {
    CallSpecView()
}
