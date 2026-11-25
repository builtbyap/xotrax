import Foundation
import Observation

/// Connects to the launch monitor (Jetson) over a WebSocket and publishes each shot.
/// Every screen watches `lastShot` with `.onChange` and handles the shot its own way.
@Observable
final class LaunchMonitorService {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case simulating
        case failed(String)

        var label: String {
            switch self {
            case .disconnected: return "Not connected"
            case .connecting: return "Connecting…"
            case .connected: return "Monitor connected"
            case .simulating: return "Simulator"
            case .failed(let msg): return "Error: \(msg)"
            }
        }

        var isLive: Bool { self == .connected || self == .simulating }
    }

    private(set) var state: ConnectionState = .disconnected
    private(set) var lastShot: Shot?
    private(set) var shotCount = 0

    /// Club the player has selected; sent to the monitor and used to tag shots.
    var currentClub: Club = .sevenIron {
        didSet { sendClub() }
    }

    var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "monitorHost") }
    }
    var port: Int {
        didSet { UserDefaults.standard.set(port, forKey: "monitorPort") }
    }
    var useSimulator: Bool {
        didSet {
            UserDefaults.standard.set(useSimulator, forKey: "useSimulator")
            start()
        }
    }
    var simulatorConsistency: Double = 0.6

    private var task: URLSessionWebSocketTask?
    private var wantsConnection = false
    private let decoder = JSONDecoder()

    init() {
        let d = UserDefaults.standard
        host = d.string(forKey: "monitorHost") ?? "192.168.1.50"
        let savedPort = d.integer(forKey: "monitorPort")
        port = savedPort == 0 ? 8765 : savedPort
        // Default to the simulator so the app works out of the box in Xcode.
        useSimulator = d.object(forKey: "useSimulator") as? Bool ?? true
    }

    // MARK: - Lifecycle

    func start() {
        disconnect()
        if useSimulator {
            state = .simulating
        } else {
            connect()
        }
    }

    func connect() {
        guard let url = URL(string: "ws://\(host):\(port)/shots") else {
            state = .failed("Bad address")
            return
        }
        wantsConnection = true
        state = .connecting
        let task = URLSession.shared.webSocketTask(with: url)
        self.task = task
        task.resume()
        // A ping confirms the socket actually opened.
        task.sendPing { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.task === task else { return }
                if let error {
                    self.handleFailure(error)
                } else {
                    self.state = .connected
                    self.sendClub()
                }
            }
        }
        receive(on: task)
    }

    func disconnect() {
        wantsConnection = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        if state != .simulating { state = .disconnected }
    }

    // MARK: - Shots

    /// Produces a fake shot (Simulator mode, or the "Test shot" button).
    func simulateShot() {
        publish(ShotSimulator.generate(club: currentClub, consistency: simulatorConsistency))
    }

    private func publish(_ shot: Shot) {
        lastShot = shot
        shotCount += 1
    }

    private func receive(on task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.task === task else { return }
                switch result {
                case .success(let message):
                    self.handle(message)
                    self.receive(on: task)
                case .failure(let error):
                    self.handleFailure(error)
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case .string(let text): data = text.data(using: .utf8)
        case .data(let d): data = d
        @unknown default: data = nil
        }
        guard let data,
              let payload = try? decoder.decode(MonitorShotPayload.self, from: data),
              payload.type == nil || payload.type == "shot" else { return }
        publish(payload.toShot(defaultClub: currentClub))
    }

    private func handleFailure(_ error: Error) {
        task = nil
        state = .failed(error.localizedDescription)
        guard wantsConnection else { return }
        // Auto-reconnect.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.wantsConnection, !self.useSimulator, self.task == nil else { return }
            self.connect()
        }
    }

    private func sendClub() {
        guard let task, state == .connected else { return }
        let msg = #"{"type":"club","club":"\#(currentClub.rawValue)"}"#
        task.send(.string(msg)) { _ in }
    }
}
