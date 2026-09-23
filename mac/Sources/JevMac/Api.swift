import Foundation

struct ApiError: LocalizedError {
    let errorDescription: String?
    init(_ m: String) { errorDescription = m }
}

/// POST JSON; retries 429/529 twice with backoff. Keys are never logged.
enum Api {
    static func post(_ url: String, key: String, body: [String: Any]) async throws -> [String: Any] {
        guard let u = URL(string: url) else { throw ApiError("Bad URL: \(url)") }
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.timeoutInterval = 40
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if url.contains("openrouter.ai") {
            req.setValue("https://jev-assistant.local", forHTTPHeaderField: "HTTP-Referer")
            req.setValue("Jev Assistant", forHTTPHeaderField: "X-Title")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        for attempt in 0..<3 {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if (code == 429 || code == 529) && attempt < 2 {
                try await Task.sleep(nanoseconds: UInt64(1_000_000_000) << UInt64(attempt))
                continue
            }
            guard (200..<300).contains(code) else {
                throw ApiError("HTTP \(code): \(String(decoding: data.prefix(120), as: UTF8.self))")
            }
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        throw ApiError("Service busy, try again")
    }
}
