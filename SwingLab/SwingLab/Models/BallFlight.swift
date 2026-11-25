import Foundation

/// Simple 3D golf ball flight model (gravity + drag + Magnus lift, with spin decay).
/// Calibrated to land within a few percent of typical tour carries. Used when the
/// monitor sends only launch data, and to draw flight paths.
enum BallFlight {
    /// x = downrange, y = height, z = lateral (+ right). All in yards.
    struct Point: Hashable {
        var x: Double
        var y: Double
        var z: Double
    }

    struct Result {
        var points: [Point]
        var carry: Double        // yards
        var roll: Double         // yards
        var apex: Double         // feet
        var side: Double         // yards (+ right)
        var landingAngle: Double // degrees
        var hangTime: Double     // seconds
    }

    static func simulate(ballSpeed mph: Double,
                         launchAngle: Double,
                         launchDirection: Double,
                         spinRate rpm: Double,
                         spinAxis: Double) -> Result {
        let mass = 0.04593, radius = 0.021335, rho = 1.225, g = 9.81
        let area = Double.pi * radius * radius
        let toYards = 1.09361

        let v0 = max(mph, 1) * 0.44704
        let la = launchAngle * .pi / 180
        let ld = launchDirection * .pi / 180
        let axis = spinAxis * .pi / 180

        var vx = v0 * cos(la) * cos(ld)
        var vy = v0 * sin(la)
        var vz = v0 * cos(la) * sin(ld)
        var x = 0.0, y = 0.0, z = 0.0
        var omega = max(rpm, 0) * 2 * .pi / 60
        let dt = 0.005
        var t = 0.0
        var apex = 0.0
        var points: [Point] = [Point(x: 0, y: 0, z: 0)]
        var step = 0

        // Spin axis unit vector (backspin about +z, tilted by spin axis).
        let ox = 0.0, oy = -sin(axis), oz = cos(axis)

        while t < 15 {
            let speed = max(sqrt(vx * vx + vy * vy + vz * vz), 0.1)
            let s = radius * omega / speed
            let cd = 0.22 + 0.20 * s
            let cl = min(0.30, 0.085 + 0.75 * s)
            let q = 0.5 * rho * area * speed * speed

            let ux = vx / speed, uy = vy / speed, uz = vz / speed
            // Magnus direction = spin axis × velocity direction
            let cx = oy * uz - oz * uy
            let cy = oz * ux - ox * uz
            let cz = ox * uy - oy * ux

            let ax = (-cd * q * ux + cl * q * cx) / mass
            let ay = (-cd * q * uy + cl * q * cy) / mass - g
            let az = (-cd * q * uz + cl * q * cz) / mass

            vx += ax * dt; vy += ay * dt; vz += az * dt
            x += vx * dt; y += vy * dt; z += vz * dt
            omega *= exp(-dt / 30)
            t += dt
            apex = max(apex, y)
            step += 1
            if step % 6 == 0 { points.append(Point(x: x * toYards, y: max(y, 0) * toYards, z: z * toYards)) }
            if y < 0 && t > 0.1 { break }
        }
        points.append(Point(x: x * toYards, y: 0, z: z * toYards))

        let landing = atan2(-vy, sqrt(vx * vx + vz * vz)) * 180 / .pi
        let carry = sqrt(x * x + z * z) * toYards
        let roll = carry * min(0.15, max(0, (55 - landing) / 220))

        return Result(points: points,
                      carry: carry,
                      roll: roll,
                      apex: apex * 3.28084,
                      side: z * toYards,
                      landingAngle: landing,
                      hangTime: t)
    }
}
