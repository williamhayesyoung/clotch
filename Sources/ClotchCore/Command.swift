import Foundation

/// Commands accepted by the Clotch control socket.
public enum Command: Equatable {
    case toggle
    case show
    case hide
    case notify(color: String?)
    case clear
    case sticky(Bool)
}

/// Wire format: newline-delimited JSON objects.
/// {"cmd":"toggle"} | {"cmd":"notify","color":"#ff6600"} | {"cmd":"sticky","value":true}
private struct WireCommand: Codable {
    var cmd: String
    var color: String?
    var value: Bool?
}

public enum CommandError: Error, Equatable {
    case invalidJSON
    case unknownCommand(String)
    case missingValue
}

extension Command {
    public func encoded() -> Data {
        let wire: WireCommand
        switch self {
        case .toggle: wire = WireCommand(cmd: "toggle")
        case .show: wire = WireCommand(cmd: "show")
        case .hide: wire = WireCommand(cmd: "hide")
        case .notify(let color): wire = WireCommand(cmd: "notify", color: color)
        case .clear: wire = WireCommand(cmd: "clear")
        case .sticky(let value): wire = WireCommand(cmd: "sticky", value: value)
        }
        var data = try! JSONEncoder().encode(wire)
        data.append(0x0A)
        return data
    }

    public static func decode(_ line: Data) throws -> Command {
        guard let wire = try? JSONDecoder().decode(WireCommand.self, from: line) else {
            throw CommandError.invalidJSON
        }
        switch wire.cmd {
        case "toggle": return .toggle
        case "show": return .show
        case "hide": return .hide
        case "notify": return .notify(color: wire.color)
        case "clear": return .clear
        case "sticky":
            guard let value = wire.value else { throw CommandError.missingValue }
            return .sticky(value)
        default:
            throw CommandError.unknownCommand(wire.cmd)
        }
    }
}

/// Default location of the control socket.
public func clotchSocketPath() -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return home + "/.clotch/clotch.sock"
}
