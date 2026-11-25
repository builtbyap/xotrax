import SwiftUI

/// A target drawn on the range (Target Range / Combine).
struct RangeTarget: Hashable {
    var distance: Double      // yards downrange
    var lateral: Double = 0   // yards (+ right)
    var radius: Double        // yards
    var label: String = ""
}

/// Top-down view of the range: tee at the bottom, shots fly up the screen.
struct TopDownRangeView: View {
    let shots: [Shot]
    var highlighted: Shot?
    var targets: [RangeTarget] = []
    var minDistance: Double = 100

    private var maxDistance: Double {
        let furthest = max(shots.map(\.total).max() ?? 0, targets.map { $0.distance + $0.radius }.max() ?? 0)
        let raw = max(minDistance, furthest * 1.15)
        return (raw / 50).rounded(.up) * 50
    }

    var body: some View {
        Canvas { ctx, size in
            let maxD = maxDistance
            let bottomPad: CGFloat = 20
            let scale = (size.height - bottomPad - 10) / maxD
            let tee = CGPoint(x: size.width / 2, y: size.height - bottomPad)

            func point(x downrange: Double, z lateral: Double) -> CGPoint {
                CGPoint(x: tee.x + lateral * scale, y: tee.y - downrange * scale)
            }

            // Grass stripes
            let stripe = 25.0
            var d = 0.0
            var dark = false
            while d < maxD + stripe {
                let top = point(x: d + stripe, z: 0).y
                let bottom = point(x: d, z: 0).y
                ctx.fill(Path(CGRect(x: 0, y: top, width: size.width, height: bottom - top)),
                         with: .color(dark ? Theme.grassDark : Theme.grass))
                dark.toggle()
                d += stripe
            }

            // Distance lines
            let step: Double = maxD > 250 ? 50 : 25
            var line = step
            while line <= maxD {
                let y = point(x: line, z: 0).y
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                ctx.draw(Text("\(Int(line))").font(.caption2).foregroundColor(.white.opacity(0.6)),
                         at: CGPoint(x: 18, y: y - 8))
                line += step
            }

            // Target line
            var center = Path()
            center.move(to: tee)
            center.addLine(to: CGPoint(x: tee.x, y: 0))
            ctx.stroke(center, with: .color(.white.opacity(0.25)), lineWidth: 1)

            // Targets
            for t in targets {
                let c = point(x: t.distance, z: t.lateral)
                let r = t.radius * scale
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(Theme.green.opacity(0.85)))
                for ring in [0.66, 0.33] {
                    let rr = r * ring
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                               with: .color(.white.opacity(0.35)), lineWidth: 1)
                }
                // Flag
                var pole = Path()
                pole.move(to: c)
                pole.addLine(to: CGPoint(x: c.x, y: c.y - 16))
                ctx.stroke(pole, with: .color(.white), lineWidth: 1.5)
                var flag = Path()
                flag.move(to: CGPoint(x: c.x, y: c.y - 16))
                flag.addLine(to: CGPoint(x: c.x + 9, y: c.y - 12))
                flag.addLine(to: CGPoint(x: c.x, y: c.y - 8))
                ctx.fill(flag, with: .color(.red))
                if !t.label.isEmpty {
                    ctx.draw(Text(t.label).font(.caption2.bold()).foregroundColor(.white),
                             at: CGPoint(x: c.x, y: c.y + r + 8))
                }
            }

            // Shots: landing dots for all, full flight line for the highlighted one
            for shot in shots {
                let isHighlighted = shot.id == highlighted?.id
                let land = point(x: sqrt(max(shot.carry * shot.carry - shot.side * shot.side, 0)), z: shot.side)
                let rest = point(x: sqrt(max(shot.total * shot.total - shot.sideTotal * shot.sideTotal, 0)), z: shot.sideTotal)

                if isHighlighted {
                    var path = Path()
                    let pts = shot.flightPath
                    if let first = pts.first {
                        path.move(to: point(x: first.x, z: first.z))
                        for p in pts.dropFirst() { path.addLine(to: point(x: p.x, z: p.z)) }
                    }
                    ctx.stroke(path, with: .color(Theme.accentOrange), lineWidth: 2.5)
                }

                var roll = Path()
                roll.move(to: land)
                roll.addLine(to: rest)
                ctx.stroke(roll, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))

                let r: CGFloat = isHighlighted ? 6 : 4
                ctx.fill(Path(ellipseIn: CGRect(x: land.x - r, y: land.y - r, width: r * 2, height: r * 2)),
                         with: .color(isHighlighted ? Theme.accentOrange : .white.opacity(0.85)))
            }

            // Tee
            ctx.fill(Path(ellipseIn: CGRect(x: tee.x - 5, y: tee.y - 5, width: 10, height: 10)), with: .color(.white))
        }
        .background(Theme.grass)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// Side-on view of ball flight height vs. distance.
struct SideTrajectoryView: View {
    let shots: [Shot]
    var highlighted: Shot?

    var body: some View {
        Canvas { ctx, size in
            let paths = shots.map { ($0.id, $0.flightPath) }
            let maxX = max(100, paths.flatMap { $0.1.map(\.x) }.max() ?? 100) * 1.08
            let maxY = max(25, paths.flatMap { $0.1.map(\.y) }.max() ?? 25) * 1.25
            let pad: CGFloat = 18
            let sx = (size.width - pad * 2) / maxX
            let sy = (size.height - pad * 2) / maxY

            func pt(_ p: BallFlight.Point) -> CGPoint {
                CGPoint(x: pad + p.x * sx, y: size.height - pad - p.y * sy)
            }

            // Ground + distance ticks
            var ground = Path()
            ground.move(to: CGPoint(x: pad, y: size.height - pad))
            ground.addLine(to: CGPoint(x: size.width - pad, y: size.height - pad))
            ctx.stroke(ground, with: .color(.white.opacity(0.4)), lineWidth: 1)
            let step: Double = maxX > 250 ? 50 : 25
            var tick = step
            while tick < maxX {
                ctx.draw(Text("\(Int(tick))").font(.caption2).foregroundColor(.white.opacity(0.5)),
                         at: CGPoint(x: pad + tick * sx, y: size.height - 6))
                tick += step
            }

            for (id, points) in paths {
                guard let first = points.first else { continue }
                var path = Path()
                path.move(to: pt(first))
                for p in points.dropFirst() { path.addLine(to: pt(p)) }
                let isHighlighted = id == highlighted?.id
                ctx.stroke(path,
                           with: .color(isHighlighted ? Theme.accentOrange : .white.opacity(0.3)),
                           lineWidth: isHighlighted ? 2.5 : 1)
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
