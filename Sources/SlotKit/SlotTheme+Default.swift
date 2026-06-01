public extension SlotTheme {
    /// The built-in arcade theme: chunky 10×5 ASCII faces, a rainbow gradient, a 90 ms
    /// frame cadence, a 1 s minimum spin, and a flashing `JACKPOT` finale. Reproduces
    /// the original arcade look.
    static let `default`: SlotTheme = // `make` only throws on malformed symbols; the built-in art is well-formed,
        // so a failure here is a programming error worth crashing on.
        // swiftlint:disable:next force_try
        try! SlotTheme.make { theme in
            theme.cellWidth = 10
            theme.cellHeight = 5
            theme.win = seven
            theme.lose = cross
            theme.spinning = [cherry, bell, bar, diamond, seven, grapes]
            theme.colorize = SlotColorizers.rainbow
            theme.frameInterval = 0.09
            theme.minSpin = 1.0
            theme.finale = SlotFinale(text: "  ★ ★ ★   J A C K P O T   ★ ★ ★  ")
        }

    /// The winning face: a chunky `7`.
    static let seven = SlotSymbol(rows: [
        " ███████  ",
        " ▀▀▀▀██   ",
        "    ██    ",
        "   ██     ",
        "   ██     ",
    ])

    /// The losing face: a bold `X`.
    static let cross = SlotSymbol(rows: [
        " ██   ██  ",
        "  ██ ██   ",
        "   ███    ",
        "  ██ ██   ",
        " ██   ██  ",
    ])

    private static let cherry = SlotSymbol(rows: [
        "    __    ",
        "   (  )   ",
        "  _\\/_ o  ",
        " ( oo )() ",
        "  \\__/\\/  ",
    ])

    private static let bell = SlotSymbol(rows: [
        "   _.._   ",
        "  /    \\  ",
        " |      | ",
        " '------' ",
        "    oo    ",
    ])

    private static let bar = SlotSymbol(rows: [
        " ╔═════╗  ",
        " ║ BAR ║  ",
        " ╠═════╣  ",
        " ║ BAR ║  ",
        " ╚═════╝  ",
    ])

    private static let diamond = SlotSymbol(rows: [
        "    /\\    ",
        "   /  \\   ",
        "  <    >  ",
        "   \\  /   ",
        "    \\/    ",
    ])

    private static let grapes = SlotSymbol(rows: [
        "  o o o   ",
        " o o o o  ",
        "  o o o   ",
        "   o o    ",
        "    \\|    ",
    ])
}
