import AppKit
import Common

struct SplitCommand: Command {
    let args: SplitCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        io.err("'split' is unavailable in dynamic dwm-style mode. Use stack operations and layout toggles instead.")
    }
}
