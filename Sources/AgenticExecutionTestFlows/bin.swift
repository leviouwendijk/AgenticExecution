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
            "tool-plan-failure-branch-retry-resume",
            tags: [
                "agentic-execution",
                "tool-plan",
                "on-failure",
                "path",
                "resolution",
                "retry",
                "resume",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolPlanFailureBranchRetryResume()
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
        TestFlow(
            "tool-exposure-all",
            tags: [
                "agentic-execution",
                "tools",
                "exposure",
                "all",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolExposureAll()
        },
        TestFlow(
            "tool-exposure-explicit",
            tags: [
                "agentic-execution",
                "tools",
                "exposure",
                "explicit",
                "enforcement",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolExposureExplicit()
        },
        TestFlow(
            "tool-exposure-discoverable",
            tags: [
                "agentic-execution",
                "tools",
                "exposure",
                "discovery",
                "activation",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolExposureDiscoverable()
        },
        TestFlow(
            "tool-exposure-registry-preservation",
            tags: [
                "agentic-execution",
                "tools",
                "exposure",
                "registry",
                "host-only",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolExposureRegistryPreservation()
        },
        TestFlow(
            "tool-call-resolver",
            tags: [
                "agentic-execution",
                "tools",
                "resolver",
                "exposure",
                "approval",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolCallResolver()
        },
        TestFlow(
            "tool-call-resolver-observer",
            tags: [
                "agentic-execution",
                "tools",
                "resolver",
                "observer",
                "approval",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolCallResolverObserver()
        },
        TestFlow(
            "typed-agent-tool-contract",
            tags: [
                "agentic-execution",
                "tools",
                "typed",
                "erasure",
                "observations",
                "projection",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runTypedAgentToolContract()
        },
        TestFlow(
            "tool-policy-directives",
            tags: [
                "agentic-execution",
                "policy",
                "preflight",
                "approval",
                "escalation",
            ]
        ) {
            try AgenticExecutionFlowTesting
                .runToolPolicyDirectives()
        },
    ]
}
