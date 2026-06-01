@testable import SlotKit
import Testing

struct SlotColorizerTests {
    @Test
    func plainIsIdentity() {
        #expect(SlotColorizers.plain("hello", 0) == "hello")
        #expect(SlotColorizers.plain("a b c", 42) == "a b c")
    }

    @Test
    func rainbowWrapsAnsiButKeepsCharacters() {
        let colored = SlotColorizers.rainbow("hi", 0)
        #expect(colored.contains("\u{1B}["))
        #expect(colored.contains("h"))
        #expect(colored.contains("i"))
        #expect(colored.hasSuffix("\u{1B}[0m"))
    }

    @Test
    func rainbowLeavesSpacesUncolored() {
        // A run of only spaces should come back unchanged (plus the trailing reset).
        let colored = SlotColorizers.rainbow("   ", 0)
        #expect(colored == "   \u{1B}[0m")
    }
}

struct SlotGradientTests {
    @Test
    func hueWrapsEvery360Phases() {
        // phase and phase+360 feed the same hue, so the colored output is identical.
        #expect(SlotColorizers.gradient("hello", phase: 7) == SlotColorizers.gradient("hello", phase: 367))
    }

    @Test
    func boldAndNonBoldDifferInWeightPrefix() {
        let bold = SlotColorizers.gradient("x", phase: 0, bold: true)
        let plain = SlotColorizers.gradient("x", phase: 0, bold: false)
        #expect(bold.contains("[1;38;2;"))
        #expect(plain.contains("[38;2;"))
        #expect(!plain.contains("[1;38;2;"))
    }

    @Test
    func emptyStringIsJustTheReset() {
        #expect(SlotColorizers.gradient("", phase: 0) == "\u{1B}[0m")
    }

    @Test(arguments: [0, 60, 120, 180, 240, 300, 359])
    func everyHueSectorProducesValidRGB(phase: Int) {
        // Walk one character across each hue sector; output must stay well-formed
        // (an escape per non-space char, terminated by the reset) for every sector.
        let colored = SlotColorizers.gradient("X", phase: phase)
        #expect(colored.contains("\u{1B}[1;38;2;"))
        #expect(colored.contains("X"))
        #expect(colored.hasSuffix("\u{1B}[0m"))
    }
}
