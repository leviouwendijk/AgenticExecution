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
            "tool-plan-execution-policy-model",
            tags: [
                "agentic-execution",
                "tool-plan",
                "execution-policy",
                "pause",
            ]
        ) {
            try AgenticExecutionFlowTesting
                .runToolPlanExecutionPolicyModel()
        },
        TestFlow(
            "tool-plan-single-step-start",
            tags: [
                "agentic-execution",
                "tool-plan",
                "execution-policy",
                "single-step",
                "pause",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolPlanSingleStepStart()
        },
        TestFlow(
            "tool-plan-single-step-resume",
            tags: [
                "agentic-execution",
                "tool-plan",
                "execution-policy",
                "single-step",
                "resume",
                "continuous",
                "pause",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolPlanSingleStepResume()
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
