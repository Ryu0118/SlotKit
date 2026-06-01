public extension SlotTheme {
    /// The built-in arcade theme: chunky 10×5 ASCII faces, a rainbow gradient, a 90 ms
    /// frame cadence, a 1 s minimum spin, and a flashing `JACKPOT` finale. Reproduces
    /// the original arcade look.
    ///
    /// Built through the memberwise initializer (not ``make(_:)``) because the art is
    /// known-valid at compile time, so it needs no runtime dimension check.
    static let `default` = SlotTheme(
        cellWidth: 10,
        cellHeight: 5,
        spinning: [cherry, bell, bar, diamond, seven, grapes],
        win: seven,
        lose: cross,
        colorize: SlotColorizers.rainbow,
        frameInterval: 0.09,
        minSpin: 1.0,
        finale: SlotFinale(text: "  ★ ★ ★   J A C K P O T   ★ ★ ★  "),
    )

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
