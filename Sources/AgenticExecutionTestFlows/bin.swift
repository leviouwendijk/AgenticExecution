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
            "tool-plan-run-retry-resume",
            tags: [
                "agentic-execution",
                "tool-plan",
                "run",
                "suspension",
                "retry",
                "resume",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolPlanRetryAndResume()
        },
        TestFlow(
            "tool-plan-run-skip-resume",
            tags: [
                "agentic-execution",
                "tool-plan",
                "run",
                "suspension",
                "skip",
                "resume",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolPlanSkipAndResume()
        },
        TestFlow(
            "tool-plan-approval-skip-continues",
            tags: [
                "agentic-execution",
                "tool-plan",
                "approval",
                "skip",
                "continuation",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolPlanApprovalSkip()
        },
    ]
}
