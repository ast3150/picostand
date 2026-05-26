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
        if case let .transition(_, d, _) = event { lastDistanceMm = d }
        if case let .heartbeat(_, d, _) = event { lastDistanceMm = d }
        if case let .raw(d) = event { lastDistanceMm = d }
        onEvent?(event)
    }
}
