import AppKit
import Common

struct SwapCommand: Command {
    let args: SwapCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else {
            return false
        }

        guard let currentWindow = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }

        let clients = target.workspace.tilingClients
        let targetWindow: Window?
        switch args.target.val {
            case .master:
                targetWindow = clients.first
            case .direction(let direction):
                guard let currentIndex = clients.firstIndex(where: { $0 == currentWindow }) else { return false }
                let offset = (direction == .left || direction == .up) ? -1 : 1
                var idx = currentIndex + offset
                if !clients.indices.contains(idx) {
                    if !args.wrapAround { return false }
                    idx = (idx + clients.count) % clients.count
                }
                targetWindow = clients[idx]
            case .dfsRelative(let nextPrev):
                guard let currentIndex = clients.firstIndex(where: { $0 == target.windowOrNil }) else {
                    return false
                }
                var targetIndex = switch nextPrev {
                    case .dfsNext: currentIndex + 1
                    case .dfsPrev: currentIndex - 1
                }
                if !(0 ..< clients.count).contains(targetIndex) {
                    if !args.wrapAround { return false }
                    targetIndex = (targetIndex + clients.count) % clients.count
                }
                targetWindow = clients[targetIndex]
        }

        guard let targetWindow else {
            return false
        }

        swapWindows(currentWindow, targetWindow)

        if args.swapFocus {
            return targetWindow.focusWindow()
        }
        return true
    }
}
