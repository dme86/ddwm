extension Workspace {
    @MainActor func normalizeContainers() {
        flattenTilingTreeToClientList()
    }
}

extension Workspace {
    @MainActor
    private func flattenTilingTreeToClientList() {
        let root = rootTilingContainer
        root.layout = switch root.layout {
            case .monocle: .monocle
            case .tile, .tiles, .accordion: .tile
        }

        let clients = root.allLeafWindowsRecursive
        if clients.isEmpty {
            for child in root.children where child is TilingContainer {
                child.unbindFromParent()
            }
            return
        }

        for window in clients {
            _ = window.unbindFromParent()
        }
        for child in root.children {
            _ = child.unbindFromParent()
        }
        for window in clients {
            window.bind(to: root, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }
    }
}
