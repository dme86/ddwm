import AppKit
import Common
import Foundation

@MainActor
final class DwmBarController {
    static let shared = DwmBarController()

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
        let tasks = makeTaskTexts()
        let right = blocksRunner.statusText
        for window in windowsByMonitorId.values {
            window.update(leftText: left, taskLeftText: tasks.left, taskRightText: tasks.right, rightText: right)
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
            let barHeight = swiftDwmBarHeight(screen: screen)
            let frame = screen.frame
            let barFrame = NSRect(
                x: frame.minX,
                y: frame.maxY - barHeight,
                width: frame.width,
                height: barHeight
            )
            let window = windowsByMonitorId[monitor.monitorAppKitNsScreenScreensId] ?? DwmBarWindow(frame: barFrame)
            window.setNotchGapWidth(notchGapWidth(screen: screen))
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
        let dimmedFg = normalFg.withAlphaComponent(0.4)
        let dimmedBg = normalBg.withAlphaComponent(0.4)
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
                .foregroundColor: isFocused ? selectedFg : dimmedFg,
                .backgroundColor: isFocused ? selectedBg : dimmedBg,
            ]
            full.append(NSAttributedString(string: " \(workspace.name) ", attributes: attrs))
        }
        return full
    }

    private func makeTaskTexts() -> (left: NSAttributedString, right: NSAttributedString) {
        let normalFg = NSColor(hex: "#bbbbbb")
        let normalBg = NSColor(hex: "#222222")
        let selectedFg = NSColor(hex: "#1b1515")
        let selectedBg = NSColor(hex: "#818181")
        let dimmedFg = normalFg.withAlphaComponent(0.4)
        let dimmedBg = normalBg.withAlphaComponent(0.4)
        let font = NSFont(name: "Hack Nerd Font", size: 12)
            ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        let windows = focus.workspace.allLeafWindowsRecursive
        if windows.isEmpty {
            let placeholder = NSAttributedString(
                string: " - ",
                attributes: [.font: font, .foregroundColor: dimmedFg, .backgroundColor: dimmedBg]
            )
            return (placeholder, NSAttributedString(string: ""))
        }

        let focusedId = focus.windowOrNil?.windowId
        let tokenTexts = windows.map { window -> NSAttributedString in
            let rawTitle = window.app.name?.takeIf { !$0.isEmpty } ?? "window \(window.windowId)"
            let title = String(rawTitle.prefix(24))
            let isFocused = window.windowId == focusedId
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: isFocused ? selectedFg : dimmedFg,
                .backgroundColor: isFocused ? selectedBg : dimmedBg,
            ]
            return NSAttributedString(string: " \(title) ", attributes: attrs)
        }

        let splitIndex = max(1, Int(ceil(Double(tokenTexts.count) / 2.0)))
        let left = NSMutableAttributedString()
        for token in tokenTexts.prefix(splitIndex) { left.append(token) }
        let right = NSMutableAttributedString()
        for token in tokenTexts.dropFirst(splitIndex) { right.append(token) }
        return (left, right)
    }
}

func isSwiftDwmBarEnabled() -> Bool {
    ProcessInfo.processInfo.environment["DDWM_ENABLE_SWIFT_DWMBAR"] != "0"
}

@MainActor
func swiftDwmBarHeight(screen: NSScreen) -> CGFloat {
    // On notched MacBooks this matches the full menu bar area down to the notch bottom.
    let fromVisibleFrame = ceil(screen.frame.maxY - screen.visibleFrame.maxY)
    if fromVisibleFrame > 0 {
        return fromVisibleFrame
    }
    return max(22, ceil(NSStatusBar.system.thickness))
}

@MainActor
private final class DwmBarWindow: NSPanel {
    private let horizontalPadding: CGFloat = 8
    private var notchGapWidth: CGFloat = 0
    private let leftLabel = NSTextField(labelWithString: "")
    private let taskLeftLabel = NSTextField(labelWithString: "")
    private let taskRightLabel = NSTextField(labelWithString: "")
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

        taskLeftLabel.lineBreakMode = .byTruncatingTail
        taskLeftLabel.alignment = .left
        taskLeftLabel.backgroundColor = .clear
        taskLeftLabel.textColor = NSColor(hex: "#bbbbbb")
        taskLeftLabel.font = NSFont(name: "Hack Nerd Font", size: 12)
            ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        taskLeftLabel.autoresizingMask = NSView.AutoresizingMask(arrayLiteral: .width, .height)

        taskRightLabel.lineBreakMode = .byTruncatingHead
        taskRightLabel.alignment = .right
        taskRightLabel.backgroundColor = .clear
        taskRightLabel.textColor = NSColor(hex: "#bbbbbb")
        taskRightLabel.font = NSFont(name: "Hack Nerd Font", size: 12)
            ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        taskRightLabel.autoresizingMask = NSView.AutoresizingMask(arrayLiteral: .minXMargin, .height)

        rightLabel.lineBreakMode = .byTruncatingHead
        rightLabel.alignment = .right
        rightLabel.backgroundColor = .clear
        rightLabel.textColor = NSColor(hex: "#bbbbbb")
        rightLabel.font = NSFont(name: "Hack Nerd Font", size: 13)
            ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        rightLabel.autoresizingMask = NSView.AutoresizingMask(arrayLiteral: .minXMargin, .height)

        content.addSubview(leftLabel)
        content.addSubview(taskLeftLabel)
        content.addSubview(taskRightLabel)
        content.addSubview(rightLabel)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        layoutLabels()
    }

    func setNotchGapWidth(_ width: CGFloat) {
        notchGapWidth = max(0, width)
    }

    func update(leftText: NSAttributedString, taskLeftText: NSAttributedString, taskRightText: NSAttributedString, rightText: String) {
        leftLabel.attributedStringValue = leftText
        taskLeftLabel.attributedStringValue = taskLeftText
        taskRightLabel.attributedStringValue = taskRightText
        rightLabel.stringValue = rightText
        layoutLabels()
    }

    private func layoutLabels() {
        guard let contentView else { return }
        let bounds = contentView.bounds
        let rightWidth = min(bounds.width * 0.6, rightLabel.intrinsicContentSize.width + 4)
        let leftWidth = min(bounds.width * 0.28, leftLabel.intrinsicContentSize.width + 4)
        let textHeight = max(rightLabelLineHeight(), leftLabelLineHeight(), taskLabelLineHeight())
        let y = floor((bounds.height - textHeight) / 2)
        rightLabel.frame = NSRect(
            x: bounds.maxX - horizontalPadding - rightWidth,
            y: y,
            width: rightWidth,
            height: textHeight
        )
        leftLabel.frame = NSRect(
            x: horizontalPadding,
            y: y,
            width: leftWidth,
            height: textHeight
        )

        let taskStartX = leftLabel.frame.maxX + horizontalPadding
        let taskEndX = rightLabel.frame.minX - horizontalPadding
        let taskTotalWidth = max(0, taskEndX - taskStartX)

        if notchGapWidth > 0, taskTotalWidth > notchGapWidth + 20 {
            let notchStart = bounds.midX - notchGapWidth / 2
            let notchEnd = bounds.midX + notchGapWidth / 2
            let leftTaskEnd = min(taskEndX, notchStart - horizontalPadding)
            let rightTaskStart = max(taskStartX, notchEnd + horizontalPadding)
            taskLeftLabel.frame = NSRect(
                x: taskStartX,
                y: y,
                width: max(0, leftTaskEnd - taskStartX),
                height: textHeight
            )
            taskRightLabel.frame = NSRect(
                x: rightTaskStart,
                y: y,
                width: max(0, taskEndX - rightTaskStart),
                height: textHeight
            )
        } else {
            taskLeftLabel.frame = NSRect(
                x: taskStartX,
                y: y,
                width: taskTotalWidth,
                height: textHeight
            )
            taskRightLabel.frame = NSRect(
                x: taskEndX,
                y: y,
                width: 0,
                height: textHeight
            )
        }
    }

    private func rightLabelLineHeight() -> CGFloat {
        guard let font = rightLabel.font else { return 14 }
        return ceil(font.ascender - font.descender + font.leading)
    }

    private func leftLabelLineHeight() -> CGFloat {
        guard leftLabel.attributedStringValue.length > 0 else { return rightLabelLineHeight() }
        let font = leftLabel.attributedStringValue.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        guard let font else { return rightLabelLineHeight() }
        return ceil(font.ascender - font.descender + font.leading)
    }

    private func taskLabelLineHeight() -> CGFloat {
        if taskLeftLabel.attributedStringValue.length > 0 {
            let leftFont = taskLeftLabel.attributedStringValue.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
            if let leftFont {
                return ceil(leftFont.ascender - leftFont.descender + leftFont.leading)
            }
        }
        if taskRightLabel.attributedStringValue.length > 0 {
            let rightFont = taskRightLabel.attributedStringValue.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
            if let rightFont {
                return ceil(rightFont.ascender - rightFont.descender + rightFont.leading)
            }
        }
        return rightLabelLineHeight()
    }
}

@MainActor
private func notchGapWidth(screen: NSScreen) -> CGFloat {
    if #available(macOS 12.0, *) {
        guard let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea
        else {
            return 0
        }
        let left = leftArea.width
        let right = rightArea.width
        let full = screen.frame.width
        let gap = full - left - right
        if gap > 20, gap < full {
            return gap
        }
    }
    return 0
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
    private let brewUpdateScriptPath: String
    private let internetScriptPath: String
    private let kernelVersionScriptPath: String
    private let weatherScriptPath: String
    private var blocks: [DwmBarBlock] = []

    private var timers: [Int: Timer] = [:]
    private var outputsByIndex: [Int: String] = [:]
    private var inFlight: Set<Int> = []
    private var isStarted = false

    init() {
        scriptsPath = resolveScriptsPath()
        customScriptsPath = "\(scriptsPath)/custom"
        brewUpdateScriptPath = "\(scriptsPath)/brew_updates"
        internetScriptPath = "\(scriptsPath)/internet"
        kernelVersionScriptPath = "\(scriptsPath)/kernel_version"
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
        result.append(.init(command: scriptRunCommand(brewUpdateScriptPath), intervalSeconds: 3600))
        result.append(.init(command: scriptRunCommand(internetScriptPath), intervalSeconds: 15))
        result.append(.init(command: scriptRunCommand(kernelVersionScriptPath), intervalSeconds: 3600))
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
