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

enum BlockKind: String, Codable { case paragraph, bullet, task }

struct Block: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: BlockKind
    var text: String
    var done: Bool = false
    var indent: Int = 0
}

struct AppState: Codable {
    var blocks: [Block] = []
    var corner: Corner = .bottomRight
    var launchAtLogin: Bool = false
}