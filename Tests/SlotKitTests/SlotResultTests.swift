@testable import SlotKit
import Testing

struct SlotResultTests {
    @Test(arguments: [
        ([true, true, true], true),
        ([true, false, true], false),
        ([false, false], false),
        ([], true), // vacuously true
    ])
    func allPassedReflectsEveryOutcome(outcomes: [Bool], expected: Bool) {
        let result = SlotResult(outcomes: outcomes.enumerated().map { index, passed in
            SlotOutcome(label: "\(index)", passed: passed)
        })
        #expect(result.allPassed == expected)
    }
}
