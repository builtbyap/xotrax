import SwiftUI

struct ProfileView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { SettingsView() } label: {
                        Label("Launch Monitor", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    NavigationLink { GappingView() } label: {
                        Label("Club Gapping", systemImage: "chart.bar.xaxis")
                    }
                }

                Section("Sessions") {
                    if store.sessions.isEmpty {
                        Text("No saved sessions yet. Finish a Range, Target Range, Combine or Course session to see it here.")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    ForEach(store.sessions) { session in
                        NavigationLink { SessionDetailView(session: session) } label: {
                            HStack {
                                Image(systemName: session.mode.icon)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 28)
                                VStack(alignment: .leading) {
                                    Text(session.title).font(.subheadline.bold())
                                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                if let score = session.score {
                                    Text("\(score.fmt(session.mode == .combine ? 1 : 0)) \(session.scoreLabel ?? "")")
                                        .font(.caption.bold())
                                }
                            }
                        }
                    }
                    .onDelete { store.delete(at: $0) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Me")
            .toolbar { ToolbarItem(placement: .topBarLeading) { ConnectionBadge() } }
        }
    }
}

struct SessionDetailView: View {
    let session: Session
    @State private var selected: Shot?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TopDownRangeView(shots: session.shots, highlighted: selected)
                    .frame(height: 280)
                    .padding(.horizontal)
                ShotMetricsGrid(shot: selected ?? session.shots.first)
                    .padding(.horizontal)
                ShotListSection(shots: session.shots, selected: $selected)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Theme.background)
        .navigationTitle(session.mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: csv, preview: SharePreview("Shots.csv")) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    /// CSV export of every shot in the session.
    private var csv: String {
        var lines = ["time,club,ball_speed,club_speed,smash,launch_angle,launch_direction,spin_rate,spin_axis,carry,total,apex_ft,side"]
        let iso = ISO8601DateFormatter()
        for s in session.shots {
            lines.append([iso.string(from: s.timestamp), s.club.rawValue,
                          s.ballSpeed.fmt(1), s.clubSpeed.fmt(1), s.smashFactor.fmt(2),
                          s.launchAngle.fmt(1), s.launchDirection.fmt(1),
                          s.spinRate.fmt(0), s.spinAxis.fmt(1),
                          s.carry.fmt(1), s.total.fmt(1), s.apex.fmt(0), s.side.fmt(1)].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}

/// Average carry/total per club from every saved session.
struct GappingView: View {
    @Environment(SessionStore.self) private var store

    private var rows: [(club: Club, carry: Double, total: Double, count: Int)] {
        let groups = Dictionary(grouping: store.allShots, by: \.club)
        return Club.allCases.compactMap { club -> (club: Club, carry: Double, total: Double, count: Int)? in
            guard let shots = groups[club], !shots.isEmpty else { return nil }
            let n = Double(shots.count)
            return (club, shots.map(\.carry).reduce(0, +) / n, shots.map(\.total).reduce(0, +) / n, shots.count)
        }
    }

    var body: some View {
        List {
            if rows.isEmpty {
                Text("Save some sessions to build your gapping chart.")
                    .foregroundStyle(Theme.secondaryText)
            }
            let maxTotal = rows.map(\.total).max() ?? 1
            ForEach(rows, id: \.club) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.club.name).bold()
                        Spacer()
                        Text("\(row.carry.fmt(0)) / \(row.total.fmt(0)) yds")
                            .monospacedDigit()
                        Text("(\(row.count))").font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.accent.opacity(0.3))
                                .frame(width: geo.size.width * row.total / maxTotal)
                            Capsule().fill(Theme.accent)
                                .frame(width: geo.size.width * row.carry / maxTotal)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Club Gapping")
    }
}

struct SettingsView: View {
    @Environment(LaunchMonitorService.self) private var monitor
    @State private var portText = ""

    var body: some View {
        @Bindable var monitor = monitor
        Form {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(monitor.state.label)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("Use Simulator", isOn: $monitor.useSimulator)
            } footer: {
                Text("Simulator mode generates realistic shots so you can test the app in the Xcode Simulator without the hardware.")
            }

            if monitor.useSimulator {
                Section("Simulator") {
                    VStack(alignment: .leading) {
                        Text("Consistency: \(Int(monitor.simulatorConsistency * 100))%")
                        Slider(value: $monitor.simulatorConsistency, in: 0...1)
                    }
                }
            } else {
                Section {
                    TextField("Jetson IP address", text: $monitor.host)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled()
                    TextField("Port", text: $portText)
                        .keyboardType(.numberPad)
                        .onChange(of: portText) { _, new in
                            if let p = Int(new) { monitor.port = p }
                        }
                    Button(monitor.state == .connected ? "Reconnect" : "Connect") { monitor.start() }
                    if monitor.state == .connected || monitor.state == .connecting {
                        Button("Disconnect", role: .destructive) { monitor.disconnect() }
                    }
                } header: {
                    Text("Jetson connection")
                } footer: {
                    Text("Connects to ws://\(monitor.host):\(monitor.port)/shots. Your iPhone and the Jetson must be on the same Wi-Fi network.")
                }

                Section("Test") {
                    Button("Inject test shot") { monitor.simulateShot() }
                }
            }

            Section("Shots received") {
                Text("\(monitor.shotCount)")
            }
        }
        .navigationTitle("Launch Monitor")
        .onAppear { portText = String(monitor.port) }
    }
}
