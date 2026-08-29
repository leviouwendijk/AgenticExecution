import TestFlows

@main
enum AgenticExecutionFlowTestMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: AgenticExecutionFlowSuite.self
        )
    }
}

enum AgenticExecutionFlowSuite: TestFlowRegistry {
    static let title = "AgenticExecution flow tests"

    static let flows: [TestFlow] = [
        TestFlow(
            "tool-plan-run-suspend-retry",
            tags: [
                "agentic-execution",
                "tool-plan",
                "run",
                "suspension",
                "retry",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolPlanSuspensionAndRetry()
        },
    ]
}
