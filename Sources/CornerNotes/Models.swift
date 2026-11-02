import Foundation

enum Corner: String, Codable, CaseIterable, Identifiable {
    case bottomRight, bottomLeft, topRight, topLeft
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .bottomRight: return "Bottom-Right"
        case .bottomLeft:  return "Bottom-Left"
        case .topRight:    return "Top-Right"
        case .topLeft:     return "Top-Left"
        }
    }
}

enum BlockKind: String, Codable {
    case paragraph, bullet

    // Older saved notes may contain tasks. Render those as ordinary text instead
    // of rejecting the whole notes file after task support is removed.
    init(from decoder: Decoder) throws {
        self = (try decoder.singleValueContainer().decode(String.self)) == "bullet" ? .bullet : .paragraph
    }
}

struct TextRange: Codable, Hashable {
    var location: Int
    var length: Int
}

struct Block: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: BlockKind
    var text: String
    var indent: Int = 0
    var strikethroughRanges: [TextRange] = []
}

struct AppState: Codable {
    var blocks: [Block] = []
    var corner: Corner = .bottomRight
    var launchAtLogin: Bool = false
    var pinned: Bool = false

    enum CodingKeys: String, CodingKey { case blocks, corner, launchAtLogin, pinned }

    init(blocks: [Block] = [], corner: Corner = .bottomRight, launchAtLogin: Bool = false, pinned: Bool = false) {
        self.blocks = blocks
        self.corner = corner
        self.launchAtLogin = launchAtLogin
        self.pinned = pinned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        blocks = try c.decodeIfPresent([Block].self, forKey: .blocks) ?? []
        corner = try c.decodeIfPresent(Corner.self, forKey: .corner) ?? .bottomRight
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
    }
}
