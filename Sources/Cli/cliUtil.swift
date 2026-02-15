import Common
import Darwin
import Foundation

let cliClientVersionAndHash: String = "\(ddwmAppVersion) \(gitHash)"

func hasStdin() -> Bool {
    isatty(STDIN_FILENO) != 1
}
