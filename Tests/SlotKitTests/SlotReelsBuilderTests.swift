@testable import SlotKit
import Testing

struct SlotReelsBuilderTests {
    @Test
    func plainBlockProducesReelsInOrder() async {
        let result = await SlotMachine.spin(plain: true) {
            SlotReel(label: "A") { true }
            SlotReel(label: "B") { false }
        }
        #expect(result.outcomes == [
            SlotOutcome(label: "A", passed: true),
            SlotOutcome(label: "B", passed: false),
        ])
    }

    @Test
    func falseIfDropsItsReel() async {
        let includeDeploy = false
        let result = await SlotMachine.spin(plain: true) {
            SlotReel(label: "BUILD") { true }
            if includeDeploy {
                SlotReel(label: "DEPLOY") { true }
            }
        }
        #expect(result.outcomes.map(\.label) == ["BUILD"])
    }

    @Test
    func trueIfKeepsItsReel() async {
        let includeDeploy = true
        let result = await SlotMachine.spin(plain: true) {
            SlotReel(label: "BUILD") { true }
            if includeDeploy {
                SlotReel(label: "DEPLOY") { true }
            }
        }
        #expect(result.outcomes.map(\.label) == ["BUILD", "DEPLOY"])
    }

    @Test(arguments: [true, false])
    func ifElseSelectsTheRightBranch(useFastPath: Bool) async {
        let result = await SlotMachine.spin(plain: true) {
            if useFastPath {
                SlotReel(label: "FAST") { true }
            } else {
                SlotReel(label: "SLOW") { true }
            }
        }
        #expect(result.outcomes.map(\.label) == [useFastPath ? "FAST" : "SLOW"])
    }

    @Test
    func forLoopContributesOneReelPerIteration() async {
        let packages = ["core", "ui", "net"]
        let result = await SlotMachine.spin(plain: true) {
            for package in packages {
                SlotReel(label: package) { true }
            }
        }
        #expect(result.outcomes.map(\.label) == packages)
    }

    @MainActor
    @Test
    func builderIsUsableFromMainActor() async {
        // `@main` CLI entry points and SwiftUI callers are main-actor-isolated; the builder
        // closure must be `@Sendable` so the block compiles from that context (the other
        // tests run nonisolated and can't catch this).
        let result = await SlotMachine.spin(plain: true) {
            SlotReel(label: "A") { true }
        }
        #expect(result.outcomes.map(\.label) == ["A"])
    }

    @Test
    func existingArrayCanBeSplicedIn() async {
        let base = [SlotReel(label: "X") { true }, SlotReel(label: "Y") { true }]
        let result = await SlotMachine.spin(plain: true) {
            base
            SlotReel(label: "Z") { true }
        }
        #expect(result.outcomes.map(\.label) == ["X", "Y", "Z"])
    }
}
