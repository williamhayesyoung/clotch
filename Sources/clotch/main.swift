import Foundation
import ClotchCore

func usage() -> Never {
    let text = """
    usage: clotch <command>

    commands:
      toggle                     fold/unfold the tray
      show                       unfold the tray
      hide                       fold the tray
      notify [--color '#RRGGBB'] pulse the notch glow (default orange)
      notify --clear             clear any pending notification
      sticky on|off              enable/disable auto-hide

    examples:
      clotch toggle                          # bind in skhd
      clotch notify --color '#ff6600'        # claude needs input
      clotch notify --color '#9b59b6'        # hermes needs input
    """
    FileHandle.standardError.write(Data((text + "\n").utf8))
    exit(64)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("clotch: " + message + "\n").utf8))
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
guard let sub = args.first else { usage() }
args.removeFirst()

let command: Command
switch sub {
case "toggle": command = .toggle
case "show": command = .show
case "hide": command = .hide
case "notify":
    if args.contains("--clear") {
        command = .clear
    } else if let i = args.firstIndex(of: "--color") {
        guard args.count > i + 1 else { usage() }
        let hex = args[i + 1]
        guard parseHexColor(hex) != nil else { fail("invalid color '\(hex)' (expected #RRGGBB)") }
        command = .notify(color: hex)
    } else {
        command = .notify(color: nil)
    }
case "sticky":
    switch args.first {
    case "on": command = .sticky(true)
    case "off": command = .sticky(false)
    default: usage()
    }
case "clear": command = .clear
case "-h", "--help", "help": usage()
default: usage()
}

// Connect to the app's unix socket and send one command.
let path = clotchSocketPath()
let fd = socket(AF_UNIX, SOCK_STREAM, 0)
guard fd >= 0 else { fail("cannot create socket") }

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
withUnsafeMutableBytes(of: &addr.sun_path) { buf in
    path.withCString { cstr in
        _ = strlcpy(buf.baseAddress!.assumingMemoryBound(to: CChar.self), cstr, buf.count)
    }
}
let len = socklen_t(MemoryLayout<sockaddr_un>.size)
let ok = withUnsafePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
        connect(fd, sa, len)
    }
}
guard ok == 0 else {
    fail("cannot connect to \(path) — is the Clotch app running?")
}

let data = command.encoded()
_ = data.withUnsafeBytes { write(fd, $0.baseAddress, data.count) }
close(fd)
