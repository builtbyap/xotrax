import SwiftUI

/// Skills test: a fixed set of targets in random order plus driver shots.
/// Each shot scores 0–100; the combine score is the average.
struct CombineView: View {
    @Environment(LaunchMonitorService.self) private var monitor
    @Environment(SessionStore.self) private var store
    @Environment(AppState.self) private var app

    enum Phase { case intro, playing, finished }

    @State private var phase: Phase = .intro
    @State private var rounds = 1
    @State private var steps: [CombineStep] = []
    @State private var index = 0
    @State private var lastScore: Double?

    static let distances: [Double] = [60, 70, 80, 90, 100, 120, 140, 160, 180]

    private var current: CombineStep? { steps.indices.contains(index) ? steps[index] : nil }
    private var completed: [CombineStep] { steps.filter { $0.shot != nil } }
    private var combineScore: Double {
        let scores = completed.compactMap(\.score)
        return scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .intro: intro
                case .playing: playing
                case .finished: finished
                }
            }
            .background(Theme.background)
            .navigationTitle("Combine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ConnectionBadge() }
                if phase == .playing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Quit", role: .destructive) { phase = .intro }
                    }
                }
            }
        }
        .onChange(of: monitor.lastShot) { _, shot in
            guard app.tab == .combine, phase == .playing, let shot else { return }
            record(shot)
        }
    }

    // MARK: - Intro

    private var intro: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 30)
                Text("Skills Combine").font(.largeTitle.bold())
                Text("Hit to \(Self.distances.count) targets from \(Int(Self.distances.first!)) to \(Int(Self.distances.last!)) yards in random order, plus a driver shot each round. Every shot scores 0–100 based on proximity. Your combine score is the average.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal)

                Picker("Length", selection: $rounds) {
                    Text("Quick · 1 round").tag(1)
                    Text("Full · 3 rounds").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Text("\(rounds * (Self.distances.count + 1)) shots")
                    .font(.headline)

                Button {
                    start()
                } label: {
                    Text("Start Combine")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.black)
                }
                .padding(.horizontal)

                if let best = store.sessions.filter({ $0.mode == .combine }).compactMap(\.score).max() {
                    Text("Personal best: \(best.fmt(1))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }

    // MARK: - Playing

    private var playing: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let step = current {
                    VStack(spacing: 4) {
                        Text("Shot \(index + 1) of \(steps.count)")
                            .font(.caption).foregroundStyle(Theme.secondaryText)
                        Text(step.isDriver ? "DRIVER" : "\(Int(step.target)) YARDS")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                        Text(step.isDriver ? "Max carry inside a 40-yard fairway" : "Suggested: \(store.suggestedClub(for: step.target).name)")
                            .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    }
                    ProgressView(value: Double(index), total: Double(steps.count))
                        .tint(Theme.accent)
                        .padding(.horizontal)

                    TopDownRangeView(shots: completed.compactMap(\.shot).suffix(1).map { $0 },
                                     highlighted: completed.last?.shot,
                                     targets: step.isDriver ? [] : [RangeTarget(distance: step.target,
                                                                                radius: max(5, step.target * 0.07),
                                                                                label: "\(Int(step.target))")],
                                     minDistance: step.isDriver ? 300 : 100)
                        .frame(height: 280)
                        .padding(.horizontal)
                }

                HStack(spacing: 8) {
                    MetricTile(title: "Last", value: lastScore.map { $0.fmt(0) } ?? "–", unit: "pts", highlight: true)
                    MetricTile(title: "Combine", value: completed.isEmpty ? "–" : combineScore.fmt(1), unit: "avg")
                    MetricTile(title: "Miss", value: completed.last?.miss.map { $0.fmt(1) } ?? "–", unit: "yds")
                }
                .padding(.horizontal)

                if let shot = completed.last?.shot {
                    CompactShotRow(shot: shot).padding(.horizontal)
                }

                SimulateShotButton()
            }
            .padding(.vertical)
        }
        .onAppear(perform: selectClubForCurrent)
    }

    // MARK: - Finished

    private var finished: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Combine Score").font(.headline).foregroundStyle(Theme.secondaryText).padding(.top, 24)
                Text(combineScore.fmt(1))
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Text(rating(combineScore)).font(.title3.bold())

                VStack(spacing: 6) {
                    ForEach(byDistance, id: \.label) { row in
                        HStack {
                            Text(row.label).bold().frame(width: 70, alignment: .leading)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.accent)
                                    .frame(width: geo.size.width * row.score / 100)
                            }
                            .frame(height: 14)
                            Text(row.score.fmt(0)).monospacedDigit().frame(width: 36, alignment: .trailing)
                        }
                        .font(.subheadline)
                    }
                }
                .card()
                .padding(.horizontal)

                Button("Done") { phase = .intro }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .foregroundStyle(.black)
            }
        }
    }

    private var byDistance: [(label: String, score: Double)] {
        let groups = Dictionary(grouping: completed) { $0.isDriver ? 999 : $0.target }
        return groups.keys.sorted().map { key -> (label: String, score: Double) in
            let scores = groups[key]!.compactMap(\.score)
            return (key == 999 ? "Driver" : "\(Int(key)) yds", scores.reduce(0, +) / Double(max(scores.count, 1)))
        }
    }

    // MARK: - Logic

    private func start() {
        var all: [CombineStep] = []
        for _ in 0..<rounds {
            all += Self.distances.shuffled().map { CombineStep(target: $0, isDriver: false) }
            all.append(CombineStep(target: 0, isDriver: true))
        }
        steps = all
        index = 0
        lastScore = nil
        phase = .playing
        selectClubForCurrent()
    }

    private func selectClubForCurrent() {
        guard let step = current else { return }
        monitor.currentClub = step.isDriver ? .driver : store.suggestedClub(for: step.target)
    }

    private func record(_ shot: Shot) {
        guard steps.indices.contains(index) else { return }
        withAnimation(.snappy) {
            steps[index].shot = shot
            lastScore = steps[index].score
            index += 1
        }
        if index >= steps.count {
            store.save(Session(mode: .combine,
                               title: "Combine · \(rounds == 1 ? "Quick" : "Full")",
                               shots: steps.compactMap(\.shot),
                               score: combineScore,
                               scoreLabel: "avg"))
            phase = .finished
        } else {
            selectClubForCurrent()
        }
    }

    private func rating(_ score: Double) -> String {
        switch score {
        case 85...: return "Tour level"
        case 75..<85: return "Scratch"
        case 65..<75: return "Low handicap"
        case 50..<65: return "Mid handicap"
        default: return "Keep grinding"
        }
    }
}

struct CombineStep: Identifiable {
    let id = UUID()
    let target: Double
    let isDriver: Bool
    var shot: Shot?

    /// Distance from the pin (yards) for target shots.
    var miss: Double? {
        guard let shot, !isDriver else { return nil }
        let downrange = sqrt(max(shot.carry * shot.carry - shot.side * shot.side, 0))
        return hypot(downrange - target, shot.side)
    }

    /// 0–100. Target shots: 100 at the pin, 0 when missing by 25% of the distance.
    /// Driver: carry/3 (300 yds = 100), halved if outside a 40-yard fairway.
    var score: Double? {
        guard let shot else { return nil }
        if isDriver {
            let base = min(100, shot.carry / 3)
            return abs(shot.side) <= 20 ? base : base * 0.5
        }
        guard let miss else { return nil }
        return max(0, 100 * (1 - (miss / target) / 0.25))
    }
}
