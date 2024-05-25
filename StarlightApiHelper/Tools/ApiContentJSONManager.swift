import Foundation
import SwiftyJSON
import SwiftApiAdapter

class ApiContentJSONManager {
    // Deserialize local JSON data to ApiContent
    func importApiContentFromLocalFile(url: URL) -> ApiContent? {
        do {
            let data = try Data(contentsOf: url)

            // Deserialize the JSON data into a Swift object
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                // Create ApiContent using the JSON dictionary
                let id = UUID() // Generate new UUID
                let name = jsonObject["name"] as? String ?? ""
                let endpoint = jsonObject["endpoint"] as? String ?? ""
                let methodRaw = jsonObject["method"] as? String ?? "GET"
                let method = HttpMethod(rawValue: methodRaw) ?? .get
                let headers = jsonObject["headers"] as? [String: String] ?? [:]

                var body = ""
                let bodyJson = jsonObject["body"] as Any
                let bodyData = try JSONSerialization.data(withJSONObject: bodyJson, options: .prettyPrinted)
                if let bodyString = String(data: bodyData, encoding: .utf8) {
                    print("JSON String:\n\(bodyString)")
                    body = bodyString
                }
                let arguments = jsonObject["arguments"] as? [String: String] ?? [:]
                let contentTypeRaw = jsonObject["contentType"] as? String ?? "TEXT"
                let contentType = ContentType(rawValue: contentTypeRaw) ?? .text
                let description = jsonObject["description"] as? String

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
                return apiContent
            } else {
                return nil
            }
        } catch {
            print("[ApiContentJSONManager] Error decoding ApiContent from local file: \(error)")
            return nil
        }
    }
}
