import AppKit
import Common
import Foundation

@MainActor
final class DwmBarController {
    static let shared = DwmBarController()

    private var barHeight: CGFloat { swiftDwmBarHeight() }
    private var screenChangeObserver: NSObjectProtocol?
    private var windowsByMonitorId: [Int: DwmBarWindow] = [:]
    private let blocksRunner = DwmBarBlocksRunner()
    private var isStarted = false

    private init() {}

    func startIfEnabled() {
        guard !isStarted else { return }
        if !isSwiftDwmBarEnabled() {
            return
        }

        isStarted = true
        blocksRunner.onUpdate = { [weak self] in
            Task { @MainActor in
                self?.refreshFromModel()
            }
        }

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildWindows()
                self?.refreshFromModel()
            }
        }

        rebuildWindows()
        blocksRunner.start()
        refreshFromModel()
    }

    func refreshFromModel() {
        guard isStarted else { return }
        rebuildWindowsIfNeeded()

        let left = makeWorkspaceText()
        let right = blocksRunner.statusText
        for window in windowsByMonitorId.values {
            window.update(leftText: left, rightText: right)
        }
    }

    private func rebuildWindowsIfNeeded() {
        let currentMonitorIds = Set(monitors.map(\.monitorAppKitNsScreenScreensId))
        let existingMonitorIds = Set(windowsByMonitorId.keys)
        if currentMonitorIds != existingMonitorIds {
            rebuildWindows()
        }
    }

    private func rebuildWindows() {
        let appScreensByMonitorId: [Int: NSScreen] = Dictionary(uniqueKeysWithValues:
            NSScreen.screens.enumerated().map { ($0.offset + 1, $0.element) })
        let visibleMonitors = monitors

        let monitorIds = Set(visibleMonitors.map(\.monitorAppKitNsScreenScreensId))
        windowsByMonitorId = windowsByMonitorId.filter { monitorIds.contains($0.key) }

        for monitor in visibleMonitors {
            guard let screen = appScreensByMonitorId[monitor.monitorAppKitNsScreenScreensId] else { continue }
            let frame = screen.frame
            let barFrame = NSRect(
                x: frame.minX,
                y: frame.maxY - barHeight,
                width: frame.width,
                height: barHeight
            )
            let window = windowsByMonitorId[monitor.monitorAppKitNsScreenScreensId] ?? DwmBarWindow(frame: barFrame)
            window.setFrame(barFrame, display: true)
            window.orderFrontRegardless()
            windowsByMonitorId[monitor.monitorAppKitNsScreenScreensId] = window
        }
    }

    private func makeWorkspaceText() -> NSAttributedString {
        let normalFg = NSColor(hex: "#bbbbbb")
        let normalBg = NSColor(hex: "#222222")
        let selectedFg = NSColor(hex: "#1b1515")
        let selectedBg = NSColor(hex: "#818181")
        let font = NSFont(name: "Hack Nerd Font", size: 13)
            ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        let visibleOrActive = Workspace.all
            .filter { !$0.isEffectivelyEmpty || $0.isVisible || config.persistentWorkspaces.contains($0.name) }
        let workspaces = visibleOrActive.isEmpty ? Workspace.all : visibleOrActive

        let full = NSMutableAttributedString()
        for workspace in workspaces {
            let isFocused = workspace == focus.workspace
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: isFocused ? selectedFg : normalFg,
                .backgroundColor: isFocused ? selectedBg : normalBg,
            ]
            full.append(NSAttributedString(string: " \(workspace.name) ", attributes: attrs))
        }
        return full
    }
}

func isSwiftDwmBarEnabled() -> Bool {
    ProcessInfo.processInfo.environment["DDWM_ENABLE_SWIFT_DWMBAR"] != "0"
}

@MainActor
func swiftDwmBarHeight() -> CGFloat {
    // Match native menu bar thickness on current macOS and keep a sane minimum.
    max(22, ceil(NSStatusBar.system.thickness))
}

@MainActor
private final class DwmBarWindow: NSPanel {
    private let horizontalPadding: CGFloat = 8
    private let leftLabel = NSTextField(labelWithString: "")
    private let rightLabel = NSTextField(labelWithString: "")

    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Keep bar above regular app windows but allow native menu bar overlay on reveal.
        level = .mainMenu
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = true
        backgroundColor = NSColor(hex: "#222222")
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false

        let content = NSView(frame: frame)
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(hex: "#222222").cgColor
        content.autoresizingMask = NSView.AutoresizingMask(arrayLiteral: .width, .height)
        contentView = content

        leftLabel.lineBreakMode = .byTruncatingTail
        leftLabel.alignment = .left
        leftLabel.backgroundColor = .clear
        leftLabel.autoresizingMask = NSView.AutoresizingMask(arrayLiteral: .width, .height)

        rightLabel.lineBreakMode = .byTruncatingHead
        rightLabel.alignment = .right
        rightLabel.backgroundColor = .clear
        rightLabel.textColor = NSColor(hex: "#bbbbbb")
        rightLabel.font = NSFont(name: "Hack Nerd Font", size: 13)
            ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        rightLabel.autoresizingMask = NSView.AutoresizingMask(arrayLiteral: .minXMargin, .height)

        content.addSubview(leftLabel)
        content.addSubview(rightLabel)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        layoutLabels()
    }

    func update(leftText: NSAttributedString, rightText: String) {
        leftLabel.attributedStringValue = leftText
        rightLabel.stringValue = rightText
        layoutLabels()
    }

    private func layoutLabels() {
        guard let contentView else { return }
        let bounds = contentView.bounds
        let rightWidth = min(bounds.width * 0.7, rightLabel.intrinsicContentSize.width + 4)
        rightLabel.frame = NSRect(
            x: bounds.maxX - horizontalPadding - rightWidth,
            y: 0,
            width: rightWidth,
            height: bounds.height
        )
        leftLabel.frame = NSRect(
            x: horizontalPadding,
            y: 0,
            width: max(0, rightLabel.frame.minX - horizontalPadding * 2),
            height: bounds.height
        )
    }
}

private struct DwmBarBlock {
    let command: String
    let intervalSeconds: TimeInterval
}

@MainActor
private final class DwmBarBlocksRunner {
    var onUpdate: (() -> Void)?

    private let delimiter = " | "
    private let fileManager = FileManager.default
    private let scriptsPath: String
    private let customScriptsPath: String
    private let weatherScriptPath: String
    private var blocks: [DwmBarBlock] = []

    private var timers: [Int: Timer] = [:]
    private var outputsByIndex: [Int: String] = [:]
    private var inFlight: Set<Int> = []
    private var isStarted = false

    init() {
        scriptsPath = resolveScriptsPath()
        customScriptsPath = "\(scriptsPath)/custom"
        weatherScriptPath = "\(scriptsPath)/weather"
    }

    var statusText: String {
        blocks.indices
            .compactMap { outputsByIndex[$0] }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: delimiter)
    }

    func start() {
        guard !isStarted else { return }
        ensureCustomScriptsDir()
        blocks = buildBlocks()
        isStarted = true
        for index in blocks.indices {
            run(index: index)
            schedule(index: index)
        }
    }

    private func schedule(index: Int) {
        let interval = max(1, blocks[index].intervalSeconds)
        timers[index] = .scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.run(index: index)
            }
        }
    }

    private func run(index: Int) {
        guard !inFlight.contains(index) else { return }
        inFlight.insert(index)
        let command = blocks[index].command
        Task.detached(priority: .utility) {
            let output = runShellCommand(command)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.outputsByIndex[index] = output
                self.inFlight.remove(index)
                self.onUpdate?()
            }
        }
    }

    private func buildBlocks() -> [DwmBarBlock] {
        var result: [DwmBarBlock] = []
        for path in listCustomScripts() {
            result.append(.init(
                command: scriptRunCommand(path),
                intervalSeconds: 30
            ))
        }
        result.append(.init(command: scriptRunCommand(weatherScriptPath), intervalSeconds: 1800))
        result.append(.init(command: "date +'%a, %d %b'", intervalSeconds: 1))
        result.append(.init(command: "date +'%H:%M:%S'", intervalSeconds: 1))
        return result
    }

    private func listCustomScripts() -> [String] {
        guard let files = try? fileManager.contentsOfDirectory(atPath: customScriptsPath) else { return [] }
        return files
            .map { "\(customScriptsPath)/\($0)" }
            .filter(isRunnableFile)
            .sorted()
    }

    private func isRunnableFile(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return false
        }
        return fileManager.isExecutableFile(atPath: path)
    }

    private func ensureCustomScriptsDir() {
        try? fileManager.createDirectory(atPath: customScriptsPath, withIntermediateDirectories: true)
    }
}

private func scriptRunCommand(_ scriptPath: String) -> String {
    let quoted = shellSingleQuoted(scriptPath)
    return "if [ -x \(quoted) ]; then \(quoted); fi"
}

private func shellSingleQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
}

private func expandTilde(_ path: String) -> String {
    if path == "~" {
        return FileManager.default.homeDirectoryForCurrentUser.path
    }
    if path.hasPrefix("~/") {
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: String(path.dropFirst(2))).path
    }
    return path
}

private func resolveScriptsPath() -> String {
    let fileManager = FileManager.default
    let rel = "script/dwmbar/scripts"
    let candidates = [
        URL(filePath: fileManager.currentDirectoryPath),
        URL(filePath: #filePath).deletingLastPathComponent(),
    ]

    for candidate in candidates {
        if let root = findProjectRoot(startingAt: candidate) {
            let scripts = root.appending(path: rel).path
            if fileManager.fileExists(atPath: scripts) {
                return scripts
            }
        }
    }
    return expandTilde("~/.config/ddwm/bar/scripts")
}

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

private func runShellCommand(_ command: String) -> String {
    let process = Process()
    process.executableURL = URL(filePath: "/bin/bash")
    process.arguments = ["-lc", command]
    let stdoutPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    } catch {
        return ""
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
