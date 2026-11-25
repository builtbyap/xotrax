import SwiftUI

struct CoursesView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section("Courses") {
                    ForEach(Course.builtIn) { course in
                        NavigationLink(value: course) {
                            HStack(spacing: 14) {
                                Image(systemName: "flag.fill")
                                    .font(.title2)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.grass, in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.name).font(.headline)
                                    Text("\(course.location) · Par \(course.par) · \(course.yards) yds")
                                        .font(.caption).foregroundStyle(Theme.secondaryText)
                                    if let best = bestScore(course) {
                                        Text("Best: \(best)").font(.caption.bold()).foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                Section {
                    Text("Each shot from your launch monitor moves the ball down the hole. Putting is automatic once you reach the green.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Courses")
            .navigationDestination(for: Course.self) { CoursePlayView(course: $0) }
            .toolbar { ToolbarItem(placement: .topBarLeading) { ConnectionBadge() } }
        }
    }

    private func bestScore(_ course: Course) -> String? {
        let scores = store.sessions
            .filter { $0.mode == .course && $0.title.hasPrefix(course.name) }
            .compactMap(\.score)
        guard let best = scores.min() else { return nil }
        let toPar = Int(best) - course.par
        return "\(Int(best)) (\(toPar == 0 ? "E" : toPar > 0 ? "+\(toPar)" : "\(toPar)"))"
    }
}

// MARK: - Play

/// Ball position on a hole: `along` = yards from the tee toward the pin, `lateral` = yards right (+) / left (−).
struct BallPosition: Hashable {
    var along: Double
    var lateral: Double
}

enum Lie: String {
    case tee = "Tee", fairway = "Fairway", rough = "Rough", green = "Green", holed = "Holed", penalty = "Penalty"
}

struct CoursePlayView: View {
    let course: Course

    @Environment(LaunchMonitorService.self) private var monitor
    @Environment(SessionStore.self) private var store
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var holeIndex = 0
    @State private var ball = BallPosition(along: 0, lateral: 0)
    @State private var trail: [BallPosition] = [BallPosition(along: 0, lateral: 0)]
    @State private var strokes = 0
    @State private var lie: Lie = .tee
    @State private var putts = 0
    @State private var scores: [Int?] = []
    @State private var allShots: [Shot] = []
    @State private var lastShot: Shot?
    @State private var message = ""
    @State private var showScorecard = false
    @State private var roundSaved = false

    private var hole: Hole { course.holes[holeIndex] }
    private var pin: BallPosition { BallPosition(along: hole.yards, lateral: 0) }
    private var remaining: Double { hypot(pin.along - ball.along, pin.lateral - ball.lateral) }
    private var holeDone: Bool { lie == .holed }
    private var roundDone: Bool { scores.count == course.holes.count && scores.allSatisfy { $0 != nil } }

    var body: some View {
        @Bindable var monitor = monitor
        ScrollView {
            VStack(spacing: 12) {
                header

                HoleCanvas(hole: hole, trail: trail, ball: ball)
                    .frame(height: 340)
                    .padding(.horizontal)

                HStack(spacing: 8) {
                    MetricTile(title: "To Pin", value: holeDone ? "–" : remaining.fmt(0), unit: lie == .green ? "\(Int(remaining * 3)) ft" : "yds", highlight: true)
                    MetricTile(title: "Lie", value: lie.rawValue, unit: "")
                    MetricTile(title: "Strokes", value: "\(strokes)", unit: "")
                    MetricTile(title: "Round", value: toParString(), unit: "to par")
                }
                .padding(.horizontal)

                if !message.isEmpty {
                    Text(message)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let lastShot {
                    CompactShotRow(shot: lastShot).padding(.horizontal)
                }

                if holeDone {
                    Button {
                        nextHole()
                    } label: {
                        Text(holeIndex + 1 < course.holes.count ? "Next Hole" : "Finish Round")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal)
                } else {
                    ClubPicker(club: $monitor.currentClub)
                    SimulateShotButton()
                }
            }
            .padding(.vertical)
        }
        .background(Theme.background)
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showScorecard = true } label: { Image(systemName: "list.number") }
            }
        }
        .sheet(isPresented: $showScorecard) {
            ScorecardView(course: course, scores: scores)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            if scores.isEmpty {
                scores = Array(repeating: nil, count: course.holes.count)
                startHole()
            }
            app.tab = .courses
        }
        .onChange(of: monitor.lastShot) { _, shot in
            guard app.tab == .courses, let shot, !holeDone, !roundSaved else { return }
            play(shot)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Hole \(hole.number)").font(.title2.bold())
                Text("Par \(hole.par) · \(Int(hole.yards)) yds").foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Text("Suggested: \(lie == .tee && hole.par > 3 ? Club.driver.name : store.suggestedClub(for: remaining).name)")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.horizontal)
    }

    // MARK: - Game logic

    private func startHole() {
        ball = BallPosition(along: 0, lateral: 0)
        trail = [ball]
        strokes = 0
        putts = 0
        lie = .tee
        lastShot = nil
        message = ""
        monitor.currentClub = hole.par > 3 ? .driver : store.suggestedClub(for: hole.yards)
    }

    private func play(_ shot: Shot) {
        strokes += 1
        allShots.append(shot)
        lastShot = shot

        // Distance after the rough penalty (ball sits down, ~8% shorter).
        let distance = shot.total * (lie == .rough ? 0.92 : 1)
        let downrange = sqrt(max(shot.total * shot.total - shot.sideTotal * shot.sideTotal, 0))
        let offline = atan2(shot.sideTotal, max(downrange, 1))   // radians, + right

        // Aim straight at the pin, then rotate by the shot's direction.
        let fa = (pin.along - ball.along) / max(remaining, 0.1)
        let fl = (pin.lateral - ball.lateral) / max(remaining, 0.1)
        let dirA = fa * cos(offline) - fl * sin(offline)
        let dirL = fl * cos(offline) + fa * sin(offline)
        var newBall = BallPosition(along: ball.along + dirA * distance, lateral: ball.lateral + dirL * distance)

        // Penalty area if way offline.
        let center = fairwayCenter(at: newBall.along)
        if abs(newBall.lateral - center) > hole.fairwayWidth / 2 + 40 {
            strokes += 1
            let side: Double = newBall.lateral > center ? 1 : -1
            newBall.lateral = center + side * (hole.fairwayWidth / 2 + 5)
            message = "Penalty area — drop, +1 stroke"
        } else {
            message = ""
        }

        withAnimation(.snappy) {
            ball = newBall
            trail.append(newBall)
        }

        let toPin = remaining
        if toPin < 1.0 {
            holeOut(putts: 0, note: strokes == 1 ? "HOLE IN ONE! 🎉" : "Holed it from off the green! 🎉")
        } else if toPin <= hole.greenRadius {
            lie = .green
            let feet = toPin * 3
            let p = feet <= 6 ? 1 : feet <= 35 ? 2 : 3
            holeOut(putts: p, note: "On the green, \(Int(feet)) ft · \(p) putt\(p == 1 ? "" : "s")")
        } else {
            let c = fairwayCenter(at: ball.along)
            let inFairway = abs(ball.lateral - c) <= hole.fairwayWidth / 2 && ball.along < hole.yards - hole.greenRadius
            if message.isEmpty { lie = inFairway ? .fairway : .rough } else { lie = .rough }
            monitor.currentClub = store.suggestedClub(for: toPin)
        }
    }

    private func holeOut(putts p: Int, note: String) {
        putts = p
        strokes += p
        lie = .holed
        scores[holeIndex] = strokes
        let diff = strokes - hole.par
        let name: String
        switch diff {
        case ...(-3): name = "Albatross"
        case -2: name = "Eagle"
        case -1: name = "Birdie"
        case 0: name = "Par"
        case 1: name = "Bogey"
        case 2: name = "Double bogey"
        default: name = "+\(diff)"
        }
        message = "\(note)\n\(name) · \(strokes)"
    }

    private func nextHole() {
        if holeIndex + 1 < course.holes.count {
            holeIndex += 1
            startHole()
        } else {
            saveRound()
            showScorecard = true
        }
    }

    private func saveRound() {
        guard !roundSaved else { return }
        roundSaved = true
        let total = scores.compactMap { $0 }.reduce(0, +)
        store.save(Session(mode: .course,
                           title: "\(course.name) · \(toParString())",
                           shots: allShots,
                           score: Double(total),
                           scoreLabel: "strokes"))
    }

    private func toParString() -> String {
        var diff = 0
        for (i, s) in scores.enumerated() { if let s { diff += s - course.holes[i].par } }
        return diff == 0 ? "E" : diff > 0 ? "+\(diff)" : "\(diff)"
    }

    private func fairwayCenter(at along: Double) -> Double {
        HoleCanvas.fairwayCenter(hole: hole, along: along)
    }
}

// MARK: - Hole drawing

struct HoleCanvas: View {
    let hole: Hole
    let trail: [BallPosition]
    let ball: BallPosition

    static func fairwayCenter(hole: Hole, along: Double) -> Double {
        let t = min(max(along / hole.yards, 0), 1)
        return hole.dogleg * sin(.pi * t)
    }

    var body: some View {
        Canvas { ctx, size in
            let extra = 30.0
            let scale = (size.height - 20) / (hole.yards + extra)
            let origin = CGPoint(x: size.width / 2, y: size.height - 12)

            func pt(_ along: Double, _ lateral: Double) -> CGPoint {
                CGPoint(x: origin.x + lateral * scale, y: origin.y - along * scale)
            }

            // Rough
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.grassDark))

            // Fairway as a polygon following the dogleg
            let start = min(40.0, hole.yards * 0.15)
            let end = hole.yards - hole.greenRadius
            if hole.par > 3, end > start {
                var left: [CGPoint] = []
                var right: [CGPoint] = []
                var a = start
                while a <= end {
                    let c = Self.fairwayCenter(hole: hole, along: a)
                    left.append(pt(a, c - hole.fairwayWidth / 2))
                    right.append(pt(a, c + hole.fairwayWidth / 2))
                    a += 5
                }
                var fw = Path()
                fw.addLines(left + right.reversed())
                fw.closeSubpath()
                ctx.fill(fw, with: .color(Theme.fairway))
            }

            // Tee box
            let tee = pt(0, 0)
            ctx.fill(Path(roundedRect: CGRect(x: tee.x - 10, y: tee.y - 6, width: 20, height: 12), cornerRadius: 3),
                     with: .color(Theme.fairway))

            // Green
            let g = pt(hole.yards, 0)
            let gr = hole.greenRadius * scale
            ctx.fill(Path(ellipseIn: CGRect(x: g.x - gr, y: g.y - gr, width: gr * 2, height: gr * 2)),
                     with: .color(Theme.green))

            // Flag
            var pole = Path()
            pole.move(to: g)
            pole.addLine(to: CGPoint(x: g.x, y: g.y - 18))
            ctx.stroke(pole, with: .color(.white), lineWidth: 1.5)
            var flag = Path()
            flag.move(to: CGPoint(x: g.x, y: g.y - 18))
            flag.addLine(to: CGPoint(x: g.x + 10, y: g.y - 14))
            flag.addLine(to: CGPoint(x: g.x, y: g.y - 10))
            ctx.fill(flag, with: .color(.red))

            // Shot trail
            if trail.count > 1 {
                var path = Path()
                path.addLines(trail.map { pt($0.along, $0.lateral) })
                ctx.stroke(path, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                for p in trail.dropLast() {
                    let c = pt(p.along, p.lateral)
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(.white.opacity(0.6)))
                }
            }

            // Ball
            let b = pt(ball.along, ball.lateral)
            ctx.fill(Path(ellipseIn: CGRect(x: b.x - 6, y: b.y - 6, width: 12, height: 12)), with: .color(.white))
            ctx.stroke(Path(ellipseIn: CGRect(x: b.x - 6, y: b.y - 6, width: 12, height: 12)), with: .color(Theme.accentOrange), lineWidth: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Scorecard

struct ScorecardView: View {
    let course: Course
    let scores: [Int?]

    var body: some View {
        NavigationStack {
            List {
                HStack {
                    Text("Hole").frame(width: 50, alignment: .leading)
                    Text("Par").frame(width: 40)
                    Text("Yds").frame(width: 50)
                    Spacer()
                    Text("Score").frame(width: 60)
                }
                .font(.caption.bold())
                .foregroundStyle(Theme.secondaryText)

                ForEach(course.holes) { hole in
                    let score = scores.indices.contains(hole.number - 1) ? scores[hole.number - 1] : nil
                    HStack {
                        Text("\(hole.number)").bold().frame(width: 50, alignment: .leading)
                        Text("\(hole.par)").frame(width: 40)
                        Text("\(Int(hole.yards))").frame(width: 50)
                        Spacer()
                        Text(score.map { "\($0)" } ?? "–")
                            .bold()
                            .frame(width: 60)
                            .foregroundStyle(color(score, par: hole.par))
                    }
                    .monospacedDigit()
                }

                HStack {
                    Text("Total").bold().frame(width: 50, alignment: .leading)
                    Text("\(course.par)").frame(width: 40)
                    Text("\(course.yards)").frame(width: 50)
                    Spacer()
                    Text("\(scores.compactMap { $0 }.reduce(0, +))").bold().frame(width: 60)
                }
                .monospacedDigit()
            }
            .navigationTitle("Scorecard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func color(_ score: Int?, par: Int) -> Color {
        guard let score else { return .secondary }
        if score < par { return Theme.accent }
        if score > par { return Theme.accentOrange }
        return .primary
    }
}
