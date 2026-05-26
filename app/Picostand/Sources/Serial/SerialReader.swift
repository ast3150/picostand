import Foundation
import ORSSerial

@MainActor
@Observable
final class SerialReader: NSObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting(path: String)
        case connected(path: String)
    }

    private(set) var connection: ConnectionState = .disconnected
    private(set) var lastDistanceMm: Int?
    private(set) var lastEventAt: Date?
    private(set) var lastValidReadingAt: Date?

    // Plausible desk-to-floor range. Outside = sensor blocked, misaimed, or returning garbage.
    private let plausibleRange = 300...1500
    var isConnected: Bool {
        if case .connected = connection { return true }
        return false
    }

    var sensorBlocked: Bool {
        guard let d = lastDistanceMm else { return false }
        return !plausibleRange.contains(d)
    }

    /// Called when the blocked status flips. `lastValidAt` is the time of the most recent
    /// plausible reading, used to truncate any open session at that moment.
    var onSensorBlockedDidChange: ((_ blocked: Bool, _ lastValidAt: Date?) -> Void)?
    private var wasBlocked: Bool = false

    private var port: ORSSerialPort?
    private var buffer = Data()
    private let manager = ORSSerialPortManager.shared()

    var onEvent: ((PicoEvent) -> Void)?

    func start() {
        autoConnect()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(portsChanged),
            name: NSNotification.Name.ORSSerialPortsWereConnected,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(portsChanged),
            name: NSNotification.Name.ORSSerialPortsWereDisconnected,
            object: nil
        )
    }

    @objc private func portsChanged() {
        if port?.isOpen != true { autoConnect() }
    }

    private func autoConnect() {
        guard let p = findPicoPort() else { return }
        connection = .connecting(path: p.path)
        p.baudRate = 115200
        p.delegate = self
        p.open()
        port = p
    }

    private func findPicoPort() -> ORSSerialPort? {
        let ports = manager.availablePorts
        // Pico USB CDC enumerates as tty.usbmodem*
        return ports.first { $0.path.contains("usbmodem") }
    }

    func send(_ json: [String: Any]) {
        guard let port, port.isOpen,
              let data = try? JSONSerialization.data(withJSONObject: json)
        else { return }
        port.send(data + Data([0x0A]))  // newline-terminated
    }
}

extension SerialReader: ORSSerialPortDelegate {
    nonisolated func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        Task { @MainActor in
            self.ingest(data)
        }
    }

    nonisolated func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        Task { @MainActor in
            self.connection = .disconnected
            self.port = nil
            self.buffer.removeAll()
        }
    }

    nonisolated func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        let path = serialPort.path
        Task { @MainActor in
            self.connection = .connected(path: path)
            // Ask Pico to re-emit any buffered transitions
            self.send(["cmd": "replay"])
        }
    }

    nonisolated func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: any Error) {
        Task { @MainActor in
            self.connection = .disconnected
        }
    }
}

@MainActor
private extension SerialReader {
    func ingest(_ data: Data) {
        buffer.append(data)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<nl]
            buffer.removeSubrange(...nl)
            guard !line.isEmpty else { continue }
            decode(Data(line))
        }
    }

    func decode(_ line: Data) {
        guard let event = try? JSONDecoder().decode(PicoEvent.self, from: line) else { return }
        lastEventAt = .now
        var newDistance: Int?
        switch event {
        case let .transition(_, d, _): newDistance = d
        case let .heartbeat(_, d, _): newDistance = d
        case let .raw(d): newDistance = d
        default: break
        }
        if let d = newDistance {
            lastDistanceMm = d
            if plausibleRange.contains(d) {
                lastValidReadingAt = lastEventAt
            }
            let nowBlocked = !plausibleRange.contains(d)
            if nowBlocked != wasBlocked {
                wasBlocked = nowBlocked
                onSensorBlockedDidChange?(nowBlocked, lastValidReadingAt)
            }
        }
        onEvent?(event)
    }
}
