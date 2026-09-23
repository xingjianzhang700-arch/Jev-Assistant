/// A plain copy of one accessibility element, so the parser runs on JSON
/// fixtures as well as on a live tree (JevMac/AXReader builds these).
public struct AXNode: Codable, Equatable {
    public var role = "", subrole = "", identifier = "", value = "", title = "", desc = ""
    public var x = 0.0, y = 0.0, w = 0.0, h = 0.0
    public var editable = false
    public var children: [AXNode] = []

    public init() {}

    enum CodingKeys: String, CodingKey {
        case role, subrole, identifier, value, title, desc, x, y, w, h, editable, children
    }

    /// Missing keys default, so hand-written fixtures stay short.
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        func s(_ k: CodingKeys) throws -> String { try c.decodeIfPresent(String.self, forKey: k) ?? "" }
        func n(_ k: CodingKeys) throws -> Double { try c.decodeIfPresent(Double.self, forKey: k) ?? 0 }
        role = try s(.role); subrole = try s(.subrole); identifier = try s(.identifier)
        value = try s(.value); title = try s(.title); desc = try s(.desc)
        x = try n(.x); y = try n(.y); w = try n(.w); h = try n(.h)
        editable = try c.decodeIfPresent(Bool.self, forKey: .editable) ?? false
        children = try c.decodeIfPresent([AXNode].self, forKey: .children) ?? []
    }

    /// Pre-order: self, then each child's subtree.
    public func flattened() -> [AXNode] { [self] + children.flatMap { $0.flattened() } }

    public var text: String { !value.isEmpty ? value : (!title.isEmpty ? title : desc) }
}
