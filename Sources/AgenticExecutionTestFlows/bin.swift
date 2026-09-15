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
            "tool-catalog",
            tags: [
                "agentic-execution",
                "tools",
                "catalog",
                "exposure",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolCatalog()
        },
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
            "tool-call-failure-envelope",
            tags: [
                "agentic-execution",
                "tools",
                "failure",
                "phase",
                "reported-failure",
                "persistence",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolCallFailureEnvelope()
        },
        TestFlow(
            "tool-mechanical-observe-retry",
            tags: [
                "agentic-execution",
                "tools",
                "recovery",
                "retry",
                "observe",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolMechanicalObserveRetry()
        },
        TestFlow(
            "tool-mechanical-mutation-recovery",
            tags: [
                "agentic-execution",
                "tools",
                "recovery",
                "reconciliation",
                "mutation",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolMechanicalMutationRecovery()
        },
        TestFlow(
            "tool-invocation-recovery-evidence",
            tags: [
                "agentic-execution",
                "tools",
                "invocation",
                "recovery",
                "evidence",
                "persistence",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolInvocationRecoveryEvidence()
        },
        TestFlow(
            "tool-plan-recovery-evidence",
            tags: [
                "agentic-execution",
                "tools",
                "tool-plan",
                "recovery",
                "evidence",
                "persistence",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolPlanRecoveryEvidence()
        },
        TestFlow(
            "tool-reconciliation",
            tags: [
                "agentic-execution",
                "tools",
                "recovery",
                "reconciliation",
                "mutation",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolReconciliation()
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
        TestFlow(
            "tool-registry-intrinsics",
            tags: [
                "agentic-execution",
                "tools",
                "registry",
                "intrinsic",
                "bootstrap",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolRegistryIntrinsics()
        },
        TestFlow(
            "tool-exposure-inspection",
            tags: [
                "agentic-execution",
                "tools",
                "exposure",
                "inspection",
            ]
        ) {
            try await AgenticExecutionFlowTesting
                .runToolExposureInspection()
        },
    ]
}