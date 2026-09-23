import Foundation
import JevCore

/// Preferences, including the API keys. Keys used to live in the keychain, but this
/// app is ad-hoc signed, so macOS asked for the login password on every read.
/// They now stay in the app's preferences and are read back with no prompt.
enum Settings {
    private static let d = UserDefaults.standard

    static var judgeKey: String {
        get { migrated("judgeKey", account: "judge") }
        set { d.set(newValue, forKey: "judgeKey"); d.set(true, forKey: "judgeKeyMigrated") }
    }
    static var replyKey: String {
        get { migrated("replyKey", account: "reply") }
        set { d.set(newValue, forKey: "replyKey"); d.set(true, forKey: "replyKeyMigrated") }
    }

    /// Copy a key out of the keychain once, without the login-password dialog.
    /// If macOS would have prompted, leave the key unset so the menu can save it.
    private static func migrated(_ key: String, account: String) -> String {
        let flag = key + "Migrated"
        if d.bool(forKey: flag) { return d.string(forKey: key) ?? "" }
        guard let copied = Keychain.get(account) else { return d.string(forKey: key) ?? "" }
        if d.string(forKey: key) == nil { d.set(copied, forKey: key) }
        d.set(true, forKey: flag)
        return d.string(forKey: key) ?? ""
    }

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
