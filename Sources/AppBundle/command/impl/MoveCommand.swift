import AppKit
import Common

struct MoveCommand: Command {
    let args: MoveCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let direction = args.direction.val
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let currentWindow = target.windowOrNil else { return io.err(noWindowIsFocused) }
        guard let parent = currentWindow.parent else { return false }

        switch parent.cases {
            case .workspace:
                return io.err("moving floating windows isn't yet supported")
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                return io.err("moving macOS fullscreen, minimized windows and windows of hidden apps isn't yet supported")
            case .macosPopupWindowsContainer:
                return false
            case .tilingContainer:
                return moveInStack(currentWindow: currentWindow, direction: direction, target: target, env: env, io: io, args: args)
        }
    }
}

@MainActor
private func moveInStack(
    currentWindow: Window,
    direction: CardinalDirection,
    target: LiveFocus,
    env: CmdEnv,
    io: CmdIo,
    args: MoveCmdArgs,
) -> Bool {
    let workspace = target.workspace
    var clients = workspace.tilingClients
    guard let index = clients.firstIndex(of: currentWindow) else { return false }

    let offset = (direction == .left || direction == .up) ? -1 : 1
    let swapIndex = index + offset

    if clients.indices.contains(swapIndex) {
        clients.swapAt(index, swapIndex)
        rebindTilingClients(workspace: workspace, clients: clients)
        return true
    }

    switch (args.boundaries, args.boundariesAction) {
        case (.workspace, .stop):
            return true
        case (.workspace, .fail):
            return false
        case (.workspace, .createImplicitContainer):
            return true
        case (.allMonitorsOuterFrame, _):
            let moveNodeToMonitorArgs = MoveNodeToMonitorCmdArgs(target: .direction(direction))
                .copy(\.windowId, currentWindow.windowId)
                .copy(\.focusFollowsWindow, focus.windowOrNil == currentWindow)
            return MoveNodeToMonitorCommand(args: moveNodeToMonitorArgs).run(env, io)
    }
}

@MainActor
private func rebindTilingClients(workspace: Workspace, clients: [Window]) {
    let root = workspace.rootTilingContainer
    for client in clients {
        client.bind(to: root, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }
}
