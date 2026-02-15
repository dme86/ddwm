import AppKit
import Common

struct LayoutCommand: Command {
    let args: LayoutCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        let targetDescription = args.toggleBetween.val.first(where: { !window.matchesDescription($0) })
            ?? args.toggleBetween.val.first.orDie()
        if window.matchesDescription(targetDescription) { return false }
        switch targetDescription {
            case .h_accordion:
                return changeTilingLayout(io, targetLayout: .tile, targetOrientation: .h, window: window)
            case .v_accordion:
                return changeTilingLayout(io, targetLayout: .tile, targetOrientation: .v, window: window)
            case .h_tiles:
                return changeTilingLayout(io, targetLayout: .tile, targetOrientation: .h, window: window)
            case .v_tiles:
                return changeTilingLayout(io, targetLayout: .tile, targetOrientation: .v, window: window)
            case .accordion:
                return changeTilingLayout(io, targetLayout: .tile, targetOrientation: nil, window: window)
            case .tiles:
                return changeTilingLayout(io, targetLayout: .tile, targetOrientation: nil, window: window)
            case .tile:
                return changeTilingLayout(io, targetLayout: .tile, targetOrientation: nil, window: window)
            case .monocle:
                return changeTilingLayout(io, targetLayout: .monocle, targetOrientation: nil, window: window)
            case .horizontal:
                return changeTilingLayout(io, targetLayout: nil, targetOrientation: .h, window: window)
            case .vertical:
                return changeTilingLayout(io, targetLayout: nil, targetOrientation: .v, window: window)
            case .tiling:
                guard let parent = window.parent else { return false }
                switch parent.cases {
                    case .macosPopupWindowsContainer:
                        return false // Impossible
                    case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                        return io.err("Can't change layout for macOS minimized, fullscreen windows or windows or hidden apps. This behavior is subject to change")
                    case .tilingContainer:
                        return true // Nothing to do
                    case .workspace(let workspace):
                        window.lastFloatingSize = try await window.getAxSize() ?? window.lastFloatingSize
                        try await window.relayoutWindow(on: workspace, forceTile: true)
                        return true
                }
            case .floating:
                let workspace = target.workspace
                window.bindAsFloatingWindow(to: workspace)
                if let size = window.lastFloatingSize { window.setAxFrame(nil, size) }
                return true
        }
    }
}

@MainActor private func changeTilingLayout(_ io: CmdIo, targetLayout: Layout?, targetOrientation: Orientation?, window: Window) -> Bool {
    guard let workspace = window.nodeWorkspace else { return false }
    let root = workspace.rootTilingContainer
    switch window.parent?.cases {
        case .tilingContainer:
            let nextOrientation = targetOrientation ?? root.orientation
            let nextLayout = targetLayout ?? root.layout
            root.layout = nextLayout
            root.changeOrientation(nextOrientation)
            return true
        case .workspace, .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
             .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
            return io.err("The window is non-tiling")
        case .none:
            return false
    }
}

extension Window {
    @MainActor
    fileprivate func matchesDescription(_ layout: LayoutCmdArgs.LayoutDescription) -> Bool {
        let root = nodeWorkspace?.rootTilingContainer
        return switch layout {
            case .accordion:   root?.layout == .tile
            case .tiles:       root?.layout == .tile
            case .tile:        root?.layout == .tile
            case .monocle:     root?.layout == .monocle
            case .horizontal:  root?.orientation == .h
            case .vertical:    root?.orientation == .v
            case .h_accordion: root.map { $0.layout == .tile && $0.orientation == .h } == true
            case .v_accordion: root.map { $0.layout == .tile && $0.orientation == .v } == true
            case .h_tiles:     root.map { $0.layout == .tile && $0.orientation == .h } == true
            case .v_tiles:     root.map { $0.layout == .tile && $0.orientation == .v } == true
            case .tiling:      parent is TilingContainer
            case .floating:    parent is Workspace
        }
    }
}
