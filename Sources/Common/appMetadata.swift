public let stableDdwmAppId: String = "dme86.ddwm"
#if DEBUG
    public let ddwmAppId: String = "dme86.ddwm.debug"
    public let ddwmAppName: String = "ddwm-Debug"
#else
    public let ddwmAppId: String = stableDdwmAppId
    public let ddwmAppName: String = "ddwm"
#endif
