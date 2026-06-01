import Foundation

/// Detects whether stdout can render an animated, colored slot machine.
///
/// Animation is shown only when stdout is an interactive terminal and color is not
/// suppressed. When it is not — pipes, redirected files, CI, `NO_COLOR` — callers
/// fall back to plain, deterministic output.
enum Terminal {
    /// `true` when stdout is an interactive TTY and `NO_COLOR` is unset.
    static var isInteractive: Bool {
        if ProcessInfo.processInfo.environment["NO_COLOR"] != nil { return false }
        if ProcessInfo.processInfo.environment["TERM"] == "dumb" { return false }
        return isatty(fileno(stdout)) != 0
    }
}
