import Foundation

enum DeskState: String, Codable, Sendable {
    case sitting, standing, unknown
}

enum PicoEvent: Sendable {
    case hello(fw: String, sit: Int, stand: Int)
    case transition(state: DeskState, d: Int, seq: Int)
    case heartbeat(state: DeskState, d: Int, seq: Int)
    case raw(d: Int)
    case cfgOk(sit: Int, stand: Int)
    case calOk(on: Bool)
    case unknown
}

extension PicoEvent: Decodable {
    private enum CodingKeys: String, CodingKey {
        case t, fw, sit, stand, state, d, seq, on
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .t)
        switch type {
        case "hello":
            self = .hello(
                fw: (try? c.decode(String.self, forKey: .fw)) ?? "?",
                sit: try c.decode(Int.self, forKey: .sit),
                stand: try c.decode(Int.self, forKey: .stand)
            )
        case "tx":
            self = .transition(
                state: try c.decode(DeskState.self, forKey: .state),
                d: try c.decode(Int.self, forKey: .d),
                seq: try c.decode(Int.self, forKey: .seq)
            )
        case "hb":
            self = .heartbeat(
                state: try c.decode(DeskState.self, forKey: .state),
                d: try c.decode(Int.self, forKey: .d),
                seq: try c.decode(Int.self, forKey: .seq)
            )
        case "raw":
            self = .raw(d: try c.decode(Int.self, forKey: .d))
        case "cfg_ok":
            self = .cfgOk(
                sit: try c.decode(Int.self, forKey: .sit),
                stand: try c.decode(Int.self, forKey: .stand)
            )
        case "cal_ok":
            self = .calOk(on: try c.decode(Bool.self, forKey: .on))
        default:
            self = .unknown
        }
    }
}
