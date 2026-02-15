import AppKit
import Common
import HotKey
import OrderedCollections

private func findProjectRoot(startingAt start: URL) -> URL? {
    var url = start
    for _ in 0 ..< 64 {
        if FileManager.default.fileExists(atPath: url.appending(component: ".git").path) {
            return url
        }
        let parent = url.deletingLastPathComponent()
        if parent.path == url.path {
            return nil
        }
        url = parent
    }
    return nil
}

func getDefaultConfigUrlFromProject() -> URL {
    let fileManager = FileManager.default
    let candidates = [
        URL(filePath: fileManager.currentDirectoryPath),
        URL(filePath: #filePath).deletingLastPathComponent(),
    ]
    for candidate in candidates {
        if let projectRoot = findProjectRoot(startingAt: candidate) {
            return projectRoot.appending(component: "docs/config-examples/default-config.toml")
        }
    }
    die("Can't locate project root (.git) from cwd '\(fileManager.currentDirectoryPath)' and #filePath '\(#filePath)'")
}

var defaultConfigUrl: URL {
    if isUnitTest {
        return getDefaultConfigUrlFromProject()
    } else {
        return Bundle.main.url(forResource: "default-config", withExtension: "toml")
            // Useful for debug builds that are not app bundles
            ?? getDefaultConfigUrlFromProject()
    }
}
@MainActor let defaultConfig: Config = {
    let parsedConfig = parseConfig(Result { try String(contentsOf: defaultConfigUrl, encoding: .utf8) }.getOrDie())
    if !parsedConfig.errors.isEmpty {
        die("Can't parse default config: \(parsedConfig.errors)")
    }
    return parsedConfig.config
}()
@MainActor var config: Config = defaultConfig // todo move to Ctx?
@MainActor var configUrl: URL = defaultConfigUrl

struct Config: ConvenienceCopyable {
    var configVersion: Int = 1
    var afterLoginCommand: [any Command] = []
    var afterStartupCommand: [any Command] = []
    var _indentForNestedContainersWithTheSameOrientation: Void = ()
    var enableNormalizationFlattenContainers: Bool = true
    var _nonEmptyWorkspacesRootContainersLayoutOnStartup: Void = ()
    var defaultRootContainerLayout: Layout = .tiles
    var defaultRootContainerOrientation: DefaultContainerOrientation = .auto
    var startAtLogin: Bool = false
    var autoReloadConfig: Bool = false
    var automaticallyUnhideMacosHiddenApps: Bool = false
    var accordionPadding: Int = 30
    var enableNormalizationOppositeOrientationForNestedContainers: Bool = true
    var persistentWorkspaces: OrderedSet<String> = []
    var execOnWorkspaceChange: [String] = [] // todo deprecate
    var keyMapping = KeyMapping()
    var execConfig: ExecConfig = ExecConfig()

    var onFocusChanged: [any Command] = []
    // var onFocusedWorkspaceChanged: [any Command] = []
    var onFocusedMonitorChanged: [any Command] = []

    var gaps: Gaps = .zero
    var workspaceToMonitorForceAssignment: [String: [MonitorDescription]] = [:]
    var modes: [String: Mode] = [:]
    var onWindowDetected: [WindowDetectedCallback] = []
    var onModeChanged: [any Command] = []
}

enum DefaultContainerOrientation: String {
    case horizontal, vertical, auto
}
