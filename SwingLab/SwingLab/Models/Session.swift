import Foundation

enum SessionMode: String, Codable, CaseIterable {
    case range = "Range"
    case targetRange = "Target Range"
    case combine = "Combine"
    case course = "Course"

    var icon: String {
        switch self {
        case .range: return "scope"
        case .targetRange: return "target"
        case .combine: return "trophy"
        case .course: return "flag"
        }
    }
}

struct Session: Identifiable, Codable, Hashable {
    var id = UUID()
    var date = Date()
    var mode: SessionMode
    var title: String
    var shots: [Shot]
    /// Mode-specific score: points (Target Range), 0–100 (Combine), strokes (Course).
    var score: Double?
    var scoreLabel: String?
}
