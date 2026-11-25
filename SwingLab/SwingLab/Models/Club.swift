import Foundation

/// Clubs in the bag. Raw values are the short codes sent to / received from the launch monitor.
enum Club: String, CaseIterable, Codable, Identifiable, Hashable {
    case driver = "DR"
    case threeWood = "3W"
    case fiveWood = "5W"
    case hybrid = "HY"
    case fourIron = "4i"
    case fiveIron = "5i"
    case sixIron = "6i"
    case sevenIron = "7i"
    case eightIron = "8i"
    case nineIron = "9i"
    case pitchingWedge = "PW"
    case gapWedge = "GW"
    case sandWedge = "SW"
    case lobWedge = "LW"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .driver: return "Driver"
        case .threeWood: return "3 Wood"
        case .fiveWood: return "5 Wood"
        case .hybrid: return "Hybrid"
        case .fourIron: return "4 Iron"
        case .fiveIron: return "5 Iron"
        case .sixIron: return "6 Iron"
        case .sevenIron: return "7 Iron"
        case .eightIron: return "8 Iron"
        case .nineIron: return "9 Iron"
        case .pitchingWedge: return "Pitching Wedge"
        case .gapWedge: return "Gap Wedge"
        case .sandWedge: return "Sand Wedge"
        case .lobWedge: return "Lob Wedge"
        }
    }

    /// Typical amateur numbers used by the simulator:
    /// (club speed mph, smash factor, launch deg, spin rpm)
    var baseline: (clubSpeed: Double, smash: Double, launch: Double, spin: Double) {
        switch self {
        case .driver: return (100, 1.47, 12.5, 2800)
        case .threeWood: return (94, 1.45, 11.5, 3700)
        case .fiveWood: return (90, 1.43, 12.5, 4400)
        case .hybrid: return (87, 1.40, 13.5, 4800)
        case .fourIron: return (84, 1.38, 13.5, 5000)
        case .fiveIron: return (82, 1.36, 14.5, 5500)
        case .sixIron: return (80, 1.34, 16.0, 6200)
        case .sevenIron: return (78, 1.33, 17.5, 6900)
        case .eightIron: return (76, 1.31, 19.5, 7600)
        case .nineIron: return (74, 1.29, 22.0, 8300)
        case .pitchingWedge: return (72, 1.25, 25.0, 8900)
        case .gapWedge: return (70, 1.21, 27.5, 9300)
        case .sandWedge: return (68, 1.17, 30.0, 9700)
        case .lobWedge: return (65, 1.12, 33.0, 10000)
        }
    }

    /// Rough carry used for club suggestions on the course before the player has data.
    var defaultCarry: Double {
        BallFlight.simulate(ballSpeed: baseline.clubSpeed * baseline.smash,
                            launchAngle: baseline.launch,
                            launchDirection: 0,
                            spinRate: baseline.spin,
                            spinAxis: 0).carry
    }
}
