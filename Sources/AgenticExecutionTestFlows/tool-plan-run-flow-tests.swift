import Agentic
import AgenticExecution
import Primitives
import TestFlows
import Foundation

enum AgenticExecutionFlowTesting {
    static func runToolPlanExecutionPolicyModel() throws -> [TestFlowDiagnostic] {
        let pause = AgentToolPlanPause(
            afterPath: "root.sequence[0]",
            afterCallID: "first",
            attemptNumber: 1,
            reason: .single_step
        )
        let state = AgentToolPlanRunState.paused(
            pause
        )

        guard AgentToolPlanExecutionPolicy.allCases == [
            .continuous,
            .single_step,
        ] else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        guard case .paused(let captured) = state,
              captured.afterPath == "root.sequence[0]",
              captured.afterCallID == "first",
              captured.attemptNumber == 1,
              captured.reason == .single_step else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        return [
            .field(
                "continuous",
                AgentToolPlanExecutionPolicy.continuous.rawValue
            ),
            .field(
                "single-step",
                AgentToolPlanExecutionPolicy.single_step.rawValue
            ),
            .field(
                "pause",
                captured.reason.rawValue
            ),
        ]
    }

    static func runToolPlanSingleStepStart() async throws -> [TestFlowDiagnostic] {
        let fixture = try makeFixture()
        let run = try await fixture.executor.start(
            fixture.plan,
            runID: "single-step-start",
            executionPolicy: .single_step
        )

        guard case .paused(let pause) = run.state,
              pause.afterPath == "root.sequence[0]",
              pause.afterCallID == "prefix",
              pause.attemptNumber == 1,
              pause.reason == .single_step else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            await fixture.probe.invocationLog(),
            "prefix",
            "single-step start executes exactly one authored call"
        )

        try Expect.equal(
            run.attempts.count,
            1,
            "single-step start records one execution attempt"
        )

        guard case .node(
            path: "root.sequence[0]",
            callID: "prefix"
        ) = run.attempts[0].scope else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        return [
            .field(
                "state",
                "paused"
            ),
            .field(
                "after",
                pause.afterCallID
            ),
            .field(
                "executed",
                await fixture.probe.invocationLog()
            ),
        ]
    }

    static func runToolPlanSingleStepResume() async throws -> [TestFlowDiagnostic] {
        let fixture = try makeFixture()
        let first = AgentToolCall(
            id: "first",
            name: "tool_plan_run_probe",
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "first"
                )
            )
        )
        let second = AgentToolCall(
            id: "second",
            name: "tool_plan_run_probe",
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "second"
                )
            )
        )
        let third = AgentToolCall(
            id: "third",
            name: "tool_plan_run_probe",
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "third"
                )
            )
        )
        let fourth = AgentToolCall(
            id: "fourth",
            name: "tool_plan_run_probe",
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "fourth"
                )
            )
        )
        let plan = AgentToolPlan(
            id: "single-step-resume-probe",
            root: .sequence(
                [
                    .call(first),
                    .call(
                        second,
                        onSuccess: [
                            .call(
                                third
                            ),
                        ]
                    ),
                    .batch(
                        [
                            .call(
                                fourth
                            ),
                        ]
                    ),
                ]
            )
        )

        let started = try await fixture.executor.start(
            plan,
            runID: "single-step-resume",
            executionPolicy: .single_step
        )

        guard case .paused(let firstPause) = started.state,
              firstPause.afterPath == "root.sequence[0]",
              firstPause.afterCallID == "first",
              firstPause.attemptNumber == 1,
              firstPause.reason == .single_step else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            await fixture.probe.invocationLog(),
            "first",
            "single-step start executes first call only"
        )

        let stepped = try await fixture.executor.resume(
            started,
            executionPolicy: .single_step
        )

        guard case .paused(let secondPause) = stepped.state,
              secondPause.afterPath == "root.sequence[1]",
              secondPause.afterCallID == "second",
              secondPause.attemptNumber == 2,
              secondPause.reason == .single_step else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            await fixture.probe.invocationLog(),
            "first,second",
            "single-step resume executes exactly one additional call"
        )

        try Expect.equal(
            stepped.revision,
            2,
            "single-step resume advances run revision"
        )

        guard stepped.attempts.count == 2,
              case .node(
                path: "root.sequence[1]",
                callID: "second"
              ) = stepped.attempts[1].scope else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        let completed = try await fixture.executor.resume(
            stepped,
            executionPolicy: .continuous
        )

        guard case .completed = completed.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            await fixture.probe.invocationLog(),
            "first,second,third,fourth",
            "continuous resume traverses success branch and batch without replay"
        )

        try Expect.equal(
            completed.attempts.count,
            4,
            "single-step traversal records one attempt per authored call"
        )

        guard case .node(
            path: "root.sequence[1].onSuccess.sequence[0]",
            callID: "third"
        ) = completed.attempts[2].scope,
              case .node(
                path: "root.sequence[2].batch[0]",
                callID: "fourth"
              ) = completed.attempts[3].scope else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            completed.revision,
            4,
            "each authored execution boundary advances run revision"
        )

        return [
            .field(
                "state",
                "completed"
            ),
            .field(
                "stepped-after",
                secondPause.afterCallID
            ),
            .field(
                "executed",
                await fixture.probe.invocationLog()
            ),
            .field(
                "revision",
                "\(completed.revision)"
            ),
        ]
    }

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
