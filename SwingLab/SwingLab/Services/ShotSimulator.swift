import Foundation

/// Generates realistic random shots so the app can be tested in the Xcode Simulator
/// without the launch monitor connected.
enum ShotSimulator {
    /// - Parameter consistency: 0 (wild) … 1 (tour-like). Controls the spread.
    static func generate(club: Club, consistency: Double = 0.6) -> Shot {
        let b = club.baseline
        let spread = 1.6 - consistency   // 0.6 … 1.6

        let clubSpeed = b.clubSpeed + gaussian() * 2.5 * spread
        // Occasional mishit: lower smash, more spin variation.
        let mishit = Double.random(in: 0...1) < 0.12 * spread
        let smash = b.smash - (mishit ? Double.random(in: 0.06...0.18) : abs(gaussian()) * 0.02 * spread)
        let ballSpeed = clubSpeed * smash
        let launch = b.launch + gaussian() * 1.8 * spread
        let direction = gaussian() * 2.2 * spread
        let spin = max(800, b.spin + gaussian() * b.spin * 0.10 * spread)
        // Slight fade bias, like most players.
        let axis = 2 + gaussian() * 7 * spread

        return Shot.fromLaunch(club: club,
                               ballSpeed: ballSpeed,
                               clubSpeed: clubSpeed,
                               launchAngle: launch,
                               launchDirection: direction,
                               spinRate: spin,
                               spinAxis: axis)
    }

    /// Standard normal random number (Box–Muller).
    private static func gaussian() -> Double {
        let u1 = Double.random(in: Double.ulpOfOne...1)
        let u2 = Double.random(in: 0...1)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }
}
