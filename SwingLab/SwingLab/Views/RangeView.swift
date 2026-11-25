import SwiftUI

/// Open practice: every shot is shown with full data, flight and dispersion.
struct RangeView: View {
    @Environment(LaunchMonitorService.self) private var monitor
    @Environment(SessionStore.self) private var store
    @Environment(AppState.self) private var app

    @State private var shots: [Shot] = []
    @State private var selected: Shot?
    @State private var showSideView = false
    @State private var filterToClub = false
    @State private var savedBanner = false

    private var visibleShots: [Shot] {
        filterToClub ? shots.filter { $0.club == monitor.currentClub } : shots
    }

    var body: some View {
        @Bindable var monitor = monitor
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ClubPicker(club: $monitor.currentClub)

                    Group {
                        if showSideView {
                            SideTrajectoryView(shots: visibleShots, highlighted: selected)
                        } else {
                            TopDownRangeView(shots: visibleShots, highlighted: selected, minDistance: 150)
                        }
                    }
                    .frame(height: 300)
                    .padding(.horizontal)
                    .overlay(alignment: .topTrailing) {
                        Picker("View", selection: $showSideView) {
                            Image(systemName: "square.split.1x2").tag(false)
                            Image(systemName: "chart.xyaxis.line").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                        .padding(.trailing, 24)
                        .padding(.top, 8)
                    }

                    SimulateShotButton()

                    ShotMetricsGrid(shot: selected)
                        .padding(.horizontal)

                    if !visibleShots.isEmpty {
                        ClubAveragesCard(shots: visibleShots.filter { $0.club == monitor.currentClub },
                                         club: monitor.currentClub)
                            .padding(.horizontal)
                    }

                    ShotListSection(shots: visibleShots, selected: $selected)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationTitle("Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ConnectionBadge() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Only \(monitor.currentClub.name)", isOn: $filterToClub)
                        Button("Save Session", systemImage: "square.and.arrow.down") { saveSession() }
                            .disabled(shots.isEmpty)
                        Button("Clear Shots", systemImage: "trash", role: .destructive) {
                            shots.removeAll(); selected = nil
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay(alignment: .top) {
                if savedBanner {
                    Text("Session saved")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Theme.accent, in: Capsule())
                        .foregroundStyle(.black)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onChange(of: monitor.lastShot) { _, shot in
            guard app.tab == .range, let shot else { return }
            withAnimation(.snappy) {
                shots.insert(shot, at: 0)
                selected = shot
            }
        }
    }

    private func saveSession() {
        let clubs = Set(shots.map(\.club)).count
        store.save(Session(mode: .range,
                           title: "Range · \(shots.count) shots · \(clubs) club\(clubs == 1 ? "" : "s")",
                           shots: shots))
        shots.removeAll()
        selected = nil
        withAnimation { savedBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { savedBanner = false } }
    }
}

struct ClubAveragesCard: View {
    let shots: [Shot]
    let club: Club

    var body: some View {
        if !shots.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(club.name) averages · \(shots.count) shot\(shots.count == 1 ? "" : "s")")
                    .font(.subheadline.bold())
                HStack {
                    stat("Carry", avg(\.carry).fmt(1))
                    stat("Total", avg(\.total).fmt(1))
                    stat("Ball", avg(\.ballSpeed).fmt(1))
                    stat("Spin", "\(Int(avg(\.spinRate)))")
                    stat("Disp.", "±\(dispersion.fmt(0))")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private func avg(_ key: KeyPath<Shot, Double>) -> Double {
        shots.map { $0[keyPath: key] }.reduce(0, +) / Double(shots.count)
    }

    /// Standard deviation of side (yards).
    private var dispersion: Double {
        let mean = avg(\.side)
        let variance = shots.map { pow($0.side - mean, 2) }.reduce(0, +) / Double(shots.count)
        return sqrt(variance)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(title).font(.caption2).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShotListSection: View {
    let shots: [Shot]
    @Binding var selected: Shot?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !shots.isEmpty {
                Text("Shots").font(.headline)
                HStack {
                    Text("#").frame(width: 28, alignment: .leading)
                    Text("Club").frame(width: 40, alignment: .leading)
                    Spacer()
                    Text("Carry").frame(width: 56)
                    Text("Ball").frame(width: 50)
                    Text("Spin").frame(width: 50)
                    Text("Side").frame(width: 50)
                }
                .font(.caption.bold())
                .foregroundStyle(Theme.secondaryText)
            }
            ForEach(Array(shots.enumerated()), id: \.element.id) { index, shot in
                Button {
                    selected = shot
                } label: {
                    HStack {
                        Text("\(shots.count - index)").frame(width: 28, alignment: .leading)
                        Text(shot.club.rawValue).bold().frame(width: 40, alignment: .leading)
                        Spacer()
                        Text(shot.carry.fmt(1)).bold().frame(width: 56)
                        Text(shot.ballSpeed.fmt(0)).frame(width: 50)
                        Text("\(Int(shot.spinRate))").frame(width: 50)
                        Text(shot.side.lateral(0)).frame(width: 50)
                    }
                    .font(.subheadline.monospacedDigit())
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(shot.id == selected?.id ? Theme.accent.opacity(0.2) : Theme.card,
                                in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
