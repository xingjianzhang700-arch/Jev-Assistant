import Foundation
import JevCore

/// Non-secret preferences. Endpoints and models default to the shared brain;
/// override with e.g. `defaults write com.jev.assistant.mac replyModel <id>`.
enum Settings {
    private static let d = UserDefaults.standard

    static var relationship: String {
        get { d.string(forKey: "relationship") ?? brainString("default_relationship") }
        set { d.set(newValue, forKey: "relationship") }
    }
    static var auto: Bool {
        get { d.object(forKey: "auto") as? Bool ?? true }
        set { d.set(newValue, forKey: "auto") }
    }
    static var judgeURL: String { d.string(forKey: "judgeURL") ?? brainString("judge_url_default") }
    static var judgeModel: String { d.string(forKey: "judgeModel") ?? brainString("judge_model_default") }
    static var replyURL: String { d.string(forKey: "replyURL") ?? brainString("reply_url_default") }
    static var replyModel: String { d.string(forKey: "replyModel") ?? brainString("reply_model_default") }
}
