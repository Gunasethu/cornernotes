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

enum NoteKind: String, Codable { case paragraph, bullet }

struct NoteBlock: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: NoteKind
    var text: String
}

struct TodoItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
    var done: Bool = false
}

struct AppState: Codable {
    var notes: [NoteBlock] = []
    var todos: [TodoItem] = []
    var corner: Corner = .bottomRight
    var launchAtLogin: Bool = false
}