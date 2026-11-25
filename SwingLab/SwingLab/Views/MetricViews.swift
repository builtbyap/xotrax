import SwiftUI

struct MetricTile: View {
    let title: String
    let value: String
    let unit: String
    var highlight = false

    var body: some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(highlight ? Theme.accent : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            Text(unit)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// The main data grid shown after every shot.
struct ShotMetricsGrid: View {
    let shot: Shot?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            MetricTile(title: "Carry", value: v(shot?.carry, 1), unit: "yds", highlight: true)
            MetricTile(title: "Total", value: v(shot?.total, 1), unit: "yds")
            MetricTile(title: "Ball Spd", value: v(shot?.ballSpeed, 1), unit: "mph")
            MetricTile(title: "Club Spd", value: v(shot?.clubSpeed, 1), unit: "mph")
            MetricTile(title: "Smash", value: v(shot?.smashFactor, 2), unit: "")
            MetricTile(title: "Launch", value: v(shot?.launchAngle, 1), unit: "deg")
            MetricTile(title: "Spin", value: shot.map { "\(Int($0.spinRate))" } ?? "–", unit: "rpm")
            MetricTile(title: "Height", value: v(shot?.apex, 0), unit: "ft")
            MetricTile(title: "Side", value: shot?.side.lateral() ?? "–", unit: "yds")
            MetricTile(title: "Launch Dir", value: shot?.launchDirection.lateral() ?? "–", unit: "deg")
            MetricTile(title: "Spin Axis", value: shot?.spinAxis.lateral() ?? "–", unit: "deg")
            MetricTile(title: "Land Ang", value: v(shot?.landingAngle, 1), unit: "deg")
        }
    }

    private func v(_ value: Double?, _ digits: Int) -> String {
        value.map { $0.fmt(digits) } ?? "–"
    }
}

/// Compact 4-number row for scoring modes.
struct CompactShotRow: View {
    let shot: Shot

    var body: some View {
        HStack(spacing: 8) {
            MetricTile(title: "Carry", value: shot.carry.fmt(1), unit: "yds", highlight: true)
            MetricTile(title: "Side", value: shot.side.lateral(), unit: "yds")
            MetricTile(title: "Ball Spd", value: shot.ballSpeed.fmt(1), unit: "mph")
            MetricTile(title: "Spin", value: "\(Int(shot.spinRate))", unit: "rpm")
        }
    }
}

struct ClubPicker: View {
    @Binding var club: Club

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Club.allCases) { c in
                        Button {
                            club = c
                        } label: {
                            Text(c.rawValue)
                                .font(.subheadline.weight(.bold))
                                .frame(minWidth: 44)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 6)
                                .background(c == club ? Theme.accent : Theme.card, in: Capsule())
                                .foregroundStyle(c == club ? .black : .white)
                        }
                        .id(c)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear { proxy.scrollTo(club, anchor: .center) }
        }
    }
}

/// Connection status pill, shown in each mode's toolbar.
struct ConnectionBadge: View {
    @Environment(LaunchMonitorService.self) private var monitor

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(shortLabel)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.card, in: Capsule())
    }

    private var color: Color {
        switch monitor.state {
        case .connected: return Theme.accent
        case .simulating: return .blue
        case .connecting: return .yellow
        case .disconnected, .failed: return .red
        }
    }

    private var shortLabel: String {
        switch monitor.state {
        case .connected: return "Live"
        case .simulating: return "Sim"
        case .connecting: return "…"
        case .disconnected: return "Offline"
        case .failed: return "Error"
        }
    }
}

/// Big button that fires a simulated shot. Shown whenever simulator mode is on.
struct SimulateShotButton: View {
    @Environment(LaunchMonitorService.self) private var monitor

    var body: some View {
        if monitor.state == .simulating {
            Button {
                withAnimation(.snappy) { monitor.simulateShot() }
            } label: {
                Label("Hit Simulated Shot", systemImage: "figure.golf")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal)
        }
    }
}
