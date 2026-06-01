import Foundation
#if canImport(Glibc)
    import Glibc
#elseif canImport(Darwin)
    import Darwin
#endif

/// Detects whether stdout can render an animated, colored slot machine.
///
/// Animation is shown only when stdout is an interactive terminal and color is not
/// suppressed. When it is not — pipes, redirected files, CI, `NO_COLOR` — callers
/// fall back to plain, deterministic output.
enum Terminal {
    /// `true` when stdout is an interactive TTY and `NO_COLOR` is unset. Environment and
    /// TTY status don't change over a process's life, so this is resolved once.
    static let isInteractive: Bool = {
        let environment = ProcessInfo.processInfo.environment
        if environment["NO_COLOR"] != nil { return false }
        if environment["TERM"] == "dumb" { return false }
        // `STDOUT_FILENO` (the constant `1`) instead of `fileno(stdout)`: on Linux the
        // global `stdout` is a `var`, which Swift 6 rejects as shared mutable state. The
        // file-descriptor constant sidesteps it and means the same thing on both platforms.
        return isatty(STDOUT_FILENO) != 0
    }()
}
