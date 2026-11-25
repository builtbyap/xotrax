import Foundation

/// One measured (or simulated) shot. Units: mph, degrees, rpm, yards, feet.
struct Shot: Identifiable, Codable, Hashable {
    var id = UUID()
    var timestamp = Date()
    var club: Club

    // Launch data (from the monitor)
    var ballSpeed: Double          // mph
    var clubSpeed: Double          // mph
    var launchAngle: Double        // deg, vertical
    var launchDirection: Double    // deg, horizontal (+ = right of target)
    var spinRate: Double           // rpm
    var spinAxis: Double           // deg (+ = curves right / fade)

    // Flight results (from the monitor, or computed by BallFlight)
    var carry: Double              // yards
    var total: Double              // yards
    var apex: Double               // feet
    var side: Double               // yards at landing (+ = right)
    var sideTotal: Double          // yards after roll (+ = right)
    var landingAngle: Double       // deg

    var smashFactor: Double { clubSpeed > 0 ? ballSpeed / clubSpeed : 0 }

    /// Builds a shot from raw launch data, computing any flight values that weren't supplied.
    static func fromLaunch(club: Club,
                           ballSpeed: Double,
                           clubSpeed: Double,
                           launchAngle: Double,
                           launchDirection: Double,
                           spinRate: Double,
                           spinAxis: Double,
                           carry: Double? = nil,
                           total: Double? = nil,
                           apex: Double? = nil,
                           side: Double? = nil) -> Shot {
        let flight = BallFlight.simulate(ballSpeed: ballSpeed,
                                         launchAngle: launchAngle,
                                         launchDirection: launchDirection,
                                         spinRate: spinRate,
                                         spinAxis: spinAxis)
        let c = carry ?? flight.carry
        let t = total ?? (c + flight.roll)
        let s = side ?? flight.side
        // Roll continues roughly along the landing direction.
        let sideTotal = c > 0 ? s * (t / c) : s
        return Shot(club: club,
                    ballSpeed: ballSpeed,
                    clubSpeed: clubSpeed,
                    launchAngle: launchAngle,
                    launchDirection: launchDirection,
                    spinRate: spinRate,
                    spinAxis: spinAxis,
                    carry: c,
                    total: t,
                    apex: apex ?? flight.apex,
                    side: s,
                    sideTotal: sideTotal,
                    landingAngle: flight.landingAngle)
    }

    /// Flight path for drawing (computed on demand, not stored).
    var flightPath: [BallFlight.Point] {
        BallFlight.simulate(ballSpeed: ballSpeed,
                            launchAngle: launchAngle,
                            launchDirection: launchDirection,
                            spinRate: spinRate,
                            spinAxis: spinAxis).points
    }
}

/// JSON the Jetson sends. Only the launch values are required — anything missing is computed in-app.
/// Example:
/// {"type":"shot","club":"7i","ball_speed":118.2,"club_speed":88.1,"launch_angle":16.4,
///  "launch_direction":-1.2,"spin_rate":6900,"spin_axis":3.5}
struct MonitorShotPayload: Decodable {
    var type: String?
    var club: String?
    var ballSpeed: Double
    var clubSpeed: Double?
    var launchAngle: Double
    var launchDirection: Double?
    var spinRate: Double?
    var spinAxis: Double?
    var carry: Double?
    var total: Double?
    var apex: Double?
    var side: Double?

    enum CodingKeys: String, CodingKey {
        case type, club, carry, total, apex, side
        case ballSpeed = "ball_speed"
        case clubSpeed = "club_speed"
        case launchAngle = "launch_angle"
        case launchDirection = "launch_direction"
        case spinRate = "spin_rate"
        case spinAxis = "spin_axis"
    }

    func toShot(defaultClub: Club) -> Shot {
        let club = self.club.flatMap { Club(rawValue: $0) } ?? defaultClub
        return Shot.fromLaunch(club: club,
                               ballSpeed: ballSpeed,
                               clubSpeed: clubSpeed ?? 0,
                               launchAngle: launchAngle,
                               launchDirection: launchDirection ?? 0,
                               spinRate: spinRate ?? club.baseline.spin,
                               spinAxis: spinAxis ?? 0,
                               carry: carry,
                               total: total,
                               apex: apex,
                               side: side)
    }
}
