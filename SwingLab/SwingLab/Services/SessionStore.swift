import Foundation
import Observation

/// Saves finished sessions as JSON in the app's Documents folder.
@Observable
final class SessionStore {
    private(set) var sessions: [Session] = []

    private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("sessions.json")
    }()

    init() { load() }

    func save(_ session: Session) {
        guard !session.shots.isEmpty else { return }
        sessions.insert(session, at: 0)
        persist()
    }

    func delete(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        persist()
    }

    var allShots: [Shot] { sessions.flatMap(\.shots) }

    /// Average carry per club across all saved shots (for gapping and course club suggestions).
    var averageCarryByClub: [Club: Double] {
        Dictionary(grouping: allShots, by: \.club).mapValues { shots in
            shots.map(\.carry).reduce(0, +) / Double(shots.count)
        }
    }

    /// Best club for a distance, using the player's own averages where available.
    func suggestedClub(for yards: Double) -> Club {
        let averages = averageCarryByClub
        let carries = Club.allCases.map { ($0, averages[$0] ?? $0.defaultCarry) }
        return carries.min { abs($0.1 - yards) < abs($1.1 - yards) }?.0 ?? .sevenIron
    }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        sessions = (try? JSONDecoder().decode([Session].self, from: data)) ?? []
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: url, options: .atomic)
        } catch {
            print("SessionStore save failed: \(error)")
        }
    }
}
