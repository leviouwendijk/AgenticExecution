import Agentic
import AgenticExecution
import Primitives
import TestFlows
import Foundation

enum AgenticExecutionFlowTesting {
    static func runToolPlanRetryAndResume() async throws -> [TestFlowDiagnostic] {
        let fixture = try makeFixture()
        let initial = try await fixture.executor.start(
            fixture.plan,
            runID: "retry-resume-run"
        )

        guard case .suspended(let initialSuspension) = initial.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        guard case .failure = initialSuspension.reason else {
            throw AgenticExecutionFlowError.unexpectedSuspensionReason
        }

        try Expect.equal(
            initialSuspension.path,
            "root.sequence[1]",
            "initial failure path"
        )

        try Expect.equal(
            initialSuspension.callID,
            "repair",
            "initial failed call"
        )

        try Expect.equal(
            await fixture.probe.invocationLog(),
            "prefix,repair",
            "failure stops untouched suffix"
        )

        let retried = try await fixture.executor.retry(
            initial
        )

        guard case .suspended(let retrySuspension) = retried.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        guard case .continuation_required(let retryResolution) = retrySuspension.reason else {
            throw AgenticExecutionFlowError.unexpectedSuspensionReason
        }

        guard case .retried(let resolvedAttemptNumber) = retryResolution.kind else {
            throw AgenticExecutionFlowError.unexpectedResolution
        }

        try Expect.equal(
            resolvedAttemptNumber,
            2,
            "retry resolution attempt"
        )

        try Expect.equal(
            retryResolution.path,
            "root.sequence[1]",
            "retry resolution retains parent path"
        )

        try Expect.equal(
            await fixture.probe.invocationLog(),
            "prefix,repair,repair",
            "retry executes failed node only"
        )

        try Expect.equal(
            retried.attempts.count,
            2,
            "retry adds one execution attempt"
        )

        try Expect.equal(
            retried.resolutions.count,
            1,
            "successful retry records explicit resolution"
        )

        try Expect.equal(
            retried.revision,
            2,
            "retry advances run revision"
        )

        let resumed = try await fixture.executor.resume(
            retried
        )

        guard case .completed = resumed.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            await fixture.probe.invocationLog(),
            "prefix,repair,repair,suffix",
            "resume executes untouched suffix only"
        )

        try Expect.equal(
            resumed.attempts.count,
            3,
            "resume adds continuation execution attempt"
        )

        try Expect.equal(
            resumed.revision,
            3,
            "resume advances run revision"
        )

        try Expect.equal(
            resumed.plan,
            fixture.plan,
            "semantic parent plan remains immutable"
        )

        let encoded = try JSONEncoder().encode(
            resumed
        )
        let decoded = try JSONDecoder().decode(
            AgentToolPlanRun.self,
            from: encoded
        )

        try Expect.equal(
            decoded,
            resumed,
            "resumed tool-plan run codable round trip"
        )

        return [
            .field(
                "state",
                "completed"
            ),
            .field(
                "attempts",
                "\(resumed.attempts.count)"
            ),
            .field(
                "revision",
                "\(resumed.revision)"
            ),
        ]
    }

    static func runToolPlanSkipAndResume() async throws -> [TestFlowDiagnostic] {
        let fixture = try makeFixture()
        let initial = try await fixture.executor.start(
            fixture.plan,
            runID: "skip-resume-run"
        )

        guard case .suspended = initial.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        let skipped = try fixture.executor.skip(
            initial
        )

        guard case .suspended(let skippedSuspension) = skipped.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        guard case .continuation_required(let skipResolution) = skippedSuspension.reason else {
            throw AgenticExecutionFlowError.unexpectedSuspensionReason
        }

        guard case .skipped = skipResolution.kind else {
            throw AgenticExecutionFlowError.unexpectedResolution
        }

        try Expect.equal(
            skipped.attempts.count,
            1,
            "skip does not execute interrupted node"
        )

        try Expect.equal(
            skipped.resolutions.count,
            1,
            "skip records explicit resolution"
        )

        try Expect.equal(
            skipped.revision,
            2,
            "skip advances revision without execution"
        )

        try Expect.equal(
            await fixture.probe.invocationLog(),
            "prefix,repair",
            "skip leaves failed node unexecuted after external repair"
        )

        let resumed = try await fixture.executor.resume(
            skipped
        )

        guard case .completed = resumed.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            await fixture.probe.invocationLog(),
            "prefix,repair,suffix",
            "resume after skip executes suffix without replay"
        )

        try Expect.equal(
            resumed.attempts.count,
            2,
            "skip plus resume has only initial and continuation executions"
        )

        try Expect.equal(
            resumed.resolutions.count,
            1,
            "skip resolution remains in run history"
        )

        try Expect.equal(
            resumed.revision,
            3,
            "skip and resume produce distinct run revisions"
        )

        return [
            .field(
                "state",
                "completed"
            ),
            .field(
                "resolution",
                "skipped"
            ),
            .field(
                "revision",
                "\(resumed.revision)"
            ),
        ]
    }

    static func runToolPlanApprovalSkip() async throws -> [TestFlowDiagnostic] {
        let probe = PlanRunProbe()
        let tool = ClosureAgentTool(
            identifier: "tool_plan_approval_skip_probe",
            description: "Records ToolPlan execution while one reviewed call is explicitly skipped.",
            risk: .boundedmutate
        ) { value, _ in
            try await probe.invoke(
                value
            )
        }
        let invoker = ToolInvoker(
            registry: ToolRegistry(
                tools: [
                    tool,
                ]
            ),
            policy: ToolExecutionPolicy(
                autonomyMode: .auto_observe
            )
        )
        let executor = AgentToolPlanRunExecutor(
            invoker: invoker
        )
        let plan = AgentToolPlan(
            id: "approval-skip-plan",
            root: .sequence(
                [
                    .call(
                        AgentToolCall(
                            id: "approval-prefix",
                            name: "tool_plan_approval_skip_probe",
                            input: try JSONToolBridge.encode(
                                RunProbeInput(
                                    marker: "approval-prefix"
                                )
                            )
                        )
                    ),
                    .call(
                        AgentToolCall(
                            id: "approval-skip",
                            name: "tool_plan_approval_skip_probe",
                            input: try JSONToolBridge.encode(
                                RunProbeInput(
                                    marker: "approval-skip"
                                )
                            )
                        )
                    ),
                    .call(
                        AgentToolCall(
                            id: "approval-suffix",
                            name: "tool_plan_approval_skip_probe",
                            input: try JSONToolBridge.encode(
                                RunProbeInput(
                                    marker: "approval-suffix"
                                )
                            )
                        )
                    ),
                ]
            )
        )

        let run = try await executor.start(
            plan,
            runID: "approval-skip-run",
            approvalHandler: SelectiveSkipApprovalHandler(
                skippedCallID: "approval-skip"
            )
        )

        guard case .completed = run.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            await probe.invocationLog(),
            "approval-prefix,approval-suffix",
            "ordinary approval skip omits only selected node and continues suffix"
        )

        guard let result = run.attempts.first?.result else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            result.outcome,
            .succeeded,
            "ordinary skipped node keeps enclosing sequence viable"
        )
        try Expect.equal(
            result.records.filter {
                $0.path.hasPrefix("root.sequence")
                    && !$0.path.contains(".on")
            }.map(\.outcome),
            [
                .succeeded,
                .skipped,
                .succeeded,
            ],
            "ordinary skip remains visible in execution records"
        )

        return [
            .field(
                "state",
                "completed"
            ),
            .field(
                "executed",
                "\(result.executedCount)"
            ),
            .field(
                "skipped",
                "\(result.skippedCount)"
            ),
        ]
    }
}

private struct SelectiveSkipApprovalHandler: ToolApprovalHandler {
    let skippedCallID: String

    func decide(
        on review: ToolInvocation.Review
    ) async throws -> ApprovalDecision {
        review.call.id == skippedCallID
            ? .skipped
            : .approved
    }
}

private extension AgenticExecutionFlowTesting {
    struct Fixture {
        let executor: AgentToolPlanRunExecutor
        let plan: AgentToolPlan
        let probe: PlanRunProbe
    }

    static func makeFixture() throws -> Fixture {
        let probe = PlanRunProbe()
        let tool = ClosureAgentTool(
            identifier: "tool_plan_run_probe",
            description: "Records execution order and fails the repair marker once."
        ) { value, _ in
            try await probe.invoke(
                value
            )
        }
        let invoker = ToolInvoker(
            registry: ToolRegistry(
                tools: [
                    tool,
                ]
            ),
            policy: ToolExecutionPolicy(
                autonomyMode: .auto_observe
            )
        )
        let prefix = AgentToolCall(
            id: "prefix",
            name: "tool_plan_run_probe",
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "prefix"
                )
            )
        )
        let repair = AgentToolCall(
            id: "repair",
            name: "tool_plan_run_probe",
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "repair"
                )
            )
        )
        let suffix = AgentToolCall(
            id: "suffix",
            name: "tool_plan_run_probe",
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "suffix"
                )
            )
        )
        let plan = AgentToolPlan(
            id: "resumable-plan-probe",
            root: .sequence(
                [
                    .call(prefix),
                    .call(repair),
                    .call(suffix),
                ]
            )
        )

        return Fixture(
            executor: AgentToolPlanRunExecutor(
                invoker: invoker
            ),
            plan: plan,
            probe: probe
        )
    }
}

private actor PlanRunProbe {
    private var invocations: [String] = []
    private var repairFailed = false

    func invoke(
        _ value: JSONValue
    ) throws -> JSONValue {
        let input = try JSONToolBridge.decode(
            RunProbeInput.self,
            from: value
        )

        invocations.append(
            input.marker
        )

        if input.marker == "repair",
           !repairFailed
        {
            repairFailed = true
            throw RunProbeError.firstRepairAttempt
        }

        return value
    }

    func invocationLog() -> String {
        invocations.joined(
            separator: ","
        )
    }
}

private struct RunProbeInput:
    Sendable,
    Codable,
    Hashable
{
    let marker: String
}

private enum RunProbeError: Error {
    case firstRepairAttempt
}

private enum AgenticExecutionFlowError: Error {
    case unexpectedRunState
    case unexpectedSuspensionReason
    case unexpectedResolution
}
