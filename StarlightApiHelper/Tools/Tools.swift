import Foundation
import SwiftApiAdapter

func formatFloatingPointsInJson(_ json: Any) -> Any {
    if var dict = json as? [String: Any] {
        for (key, value) in dict {
            dict[key] = formatFloatingPointsInJson(value)
        }
        return dict
    } else if var array = json as? [Any] {
        for (index, value) in array.enumerated() {
            array[index] = formatFloatingPointsInJson(value)
        }
        return array
    } else if let number = json as? Double {
        return Decimal(number)
    }
    return json
}

func formatJsonStringForDisplay(_ jsonString: String) -> String {
    guard let data = jsonString.data(using: .utf8) else { return jsonString }
    do {
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        let formattedJsonObject = formatFloatingPointsInJson(jsonObject)
        let formattedData = try JSONSerialization.data(withJSONObject: formattedJsonObject, options: .prettyPrinted)
        return String(data: formattedData, encoding: .utf8) ?? jsonString
    } catch {
        return jsonString
    }
}

func updateContentRecursively(_ json: inout Any, placeholder: String, userValue: String) {
    if var dict = json as? [String: Any] {
        // It's a dictionary, iterate over keys and update recursively
        for (key, value) in dict {
            var updatedValue = value
            updateContentRecursively(&updatedValue, placeholder: placeholder, userValue: userValue)
            dict[key] = updatedValue
        }
        json = dict
    } else if var array = json as? [Any] {
        // It's an array, iterate over elements and update recursively
        for i in 0..<array.count {
            var item = array[i]
            updateContentRecursively(&item, placeholder: placeholder, userValue: userValue)
            array[i] = item
        }
        json = array
    } else if let string = json as? String {
        // It's a string, check for placeholders and update if needed
        if string == placeholder {
            json = userValue
        }
    }
}

func detectPlaceholdersInJson(_ json: Any, pattern: String, detectedPlaceholders: inout [(key: String, value: String)]) {
    if let dict = json as? [String: Any] {
        // Recursively detect placeholders in dictionary values
        for value in dict.values {
            detectPlaceholdersInJson(value, pattern: pattern, detectedPlaceholders: &detectedPlaceholders)
        }
    } else if let array = json as? [Any] {
        // Recursively detect placeholders in array elements
        for item in array {
            detectPlaceholdersInJson(item, pattern: pattern, detectedPlaceholders: &detectedPlaceholders)
        }
    } else if let string = json as? String {
        // Detect placeholders in string values
        detectPlaceholdersInString(string, pattern: pattern, detectedPlaceholders: &detectedPlaceholders)
    }
}

func detectPlaceholdersInString(_ string: String, pattern: String, detectedPlaceholders: inout [(key: String, value: String)]) {
    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
        let nsString = string as NSString
        let results = regex.matches(in: string, options: [], range: NSRange(location: 0, length: nsString.length))
        for result in results {
            if let range = Range(result.range, in: string) {
                let placeholder = String(string[range])
                // Avoid inserting duplicates by checking if the placeholder is already in the list
                if !detectedPlaceholders.contains(where: {$0.key == placeholder}) {
                    detectedPlaceholders.append((key: placeholder, value: ""))
                }
            }
        }
    }
}

func replacePlaceholdersInJson(_ json: inout Any, placeholder: String, userValue: String) {
    if var dict = json as? [String: Any] {
        // It's a dictionary, iterate over keys and update recursively
        for (key, value) in dict {
            var updatedValue = value
            replacePlaceholdersInJson(&updatedValue, placeholder: placeholder, userValue: userValue)
            dict[key] = updatedValue
        }
        json = dict
    } else if var array = json as? [Any] {
        // It's an array, iterate over elements and update recursively
        for i in 0..<array.count {
            var item = array[i]
            replacePlaceholdersInJson(&item, placeholder: placeholder, userValue: userValue)
            array[i] = item
        }
        json = array
    } else if let string = json as? String {
        // It's a string, check for placeholders and update if needed
        json = replacePlaceholdersInStringValue(string, placeholder: placeholder, userValue: userValue)
    }
}

func replacePlaceholdersInStringValue(_ string: String, placeholder: String, userValue: String) -> String {
    var modifiedString = string
    _ = placeholder.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
    modifiedString = modifiedString.replacingOccurrences(of: placeholder, with: userValue, options: .literal, range: nil)
    return modifiedString
}
