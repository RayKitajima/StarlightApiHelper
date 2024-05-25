import Foundation
import SwiftyJSON
import SwiftApiAdapter

class JSONManager {
    func exportToJSON(json: JSON) -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // optional, for better readability
            let data = try encoder.encode(json)
            return data
        } catch {
            print("[ApiContentJSONManager] Error encoding json: \(error)")
            return nil
        }
    }

    func importJsonFromLocalFile(url: URL) -> String? {
        do {
            let data = try Data(contentsOf: url)
            return String(data: data, encoding: .utf8)
        } catch {
            print("[JSONManager] Error decoding ApiContent from local file: \(error)")
            return nil
        }
    }
}
