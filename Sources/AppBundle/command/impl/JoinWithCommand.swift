import AppKit
import Common

struct JoinWithCommand: Command {
    let args: JoinWithCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        io.err("'join-with' is unavailable in dynamic dwm-style mode. Use stack move/swap commands instead.")
    }
}
