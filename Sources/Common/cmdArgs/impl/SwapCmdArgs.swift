public struct SwapCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .swap,
        allowInConfig: true,
        help: swap_help_generated,
        flags: [
            "--swap-focus": trueBoolFlag(\.swapFocus),
            "--wrap-around": trueBoolFlag(\.wrapAround),
            "--window-id": optionalWindowIdFlag(),
        ],
        posArgs: [newArgParser(\.target, parseSwapTarget, mandatoryArgPlaceholder: SwapTarget.unionLiteral)],
    )

    public var target: Lateinit<SwapTarget> = .uninitialized
    public var swapFocus: Bool = false
    public var wrapAround: Bool = false

    public init(rawArgs: [String], target: SwapTarget) {
        self.commonState = .init(rawArgs.slice)
        self.target = .initialized(target)
    }

    public init(rawArgs: [String], target: CardinalOrDfsDirection) {
        self.commonState = .init(rawArgs.slice)
        let swapTarget: SwapTarget = switch target {
            case .direction(let direction): .direction(direction)
            case .dfsRelative(let nextPrev): .dfsRelative(nextPrev)
        }
        self.target = .initialized(swapTarget)
    }
}

public enum SwapTarget: Equatable, Sendable {
    case direction(CardinalDirection)
    case dfsRelative(DfsNextPrev)
    case master

    public static let unionLiteral = "\(CardinalOrDfsDirection.unionLiteral)|master"
}

public func parseSwapCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SwapCmdArgs> {
    return parseSpecificCmdArgs(SwapCmdArgs(rawArgs: args), args)
}

private func parseSwapTarget(input: ArgParserInput) -> ParsedCliArgs<SwapTarget> {
    guard let arg = input.nonFlagArgOrNil() else { return .fail("Mandatory argument is missing", advanceBy: 0) }
    if arg == "master" {
        return .succ(.master, advanceBy: 1)
    }
    return parseCardinalOrDfsDirection(i: input).map {
        switch $0 {
            case .direction(let direction): .direction(direction)
            case .dfsRelative(let nextPrev): .dfsRelative(nextPrev)
        }
    }
}
