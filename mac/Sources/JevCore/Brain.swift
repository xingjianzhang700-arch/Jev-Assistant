import Foundation

/// shared/jev-brain.json, embedded by tools/sync_brain.py (Brain.generated.swift).
public let brain: [String: Any] = {
    guard let obj = try? JSONSerialization.jsonObject(with: Data(brainJSONText.utf8)) as? [String: Any] else {
        fatalError("Brain.generated.swift is not valid JSON; rerun tools/sync_brain.py")
    }
    return obj
}()

public func brainString(_ key: String) -> String { brain[key] as? String ?? "" }

/// Display label for a Jev answer key, e.g. ("intent", "casual_chat") -> "casual chat".
public func brainLabel(_ group: String, _ key: String) -> String {
    ((brain["labels"] as? [String: Any])?[group] as? [String: String])?[key] ?? key
}
