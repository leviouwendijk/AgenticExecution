import Agentic
import AgenticExecution
import Primitives
import Schema
import TestFlows
import Foundation
import Workspace

enum AgenticExecutionFlowTesting {
    static func runToolPlanExecutionPolicyModel() throws -> [TestDiagnostic] {
        let interruption = ToolPlan.Run.Interruption(
            point: ToolPlan.Run.Point(
                path: "root.sequence[0]",
                callID: "first",
                attemptNumber: 1
            ),
            reason: .policy(
                .single_step
            )
        )
        let state = ToolPlan.Run.State.interrupted(
            interruption
        )

        guard ToolPlan.ExecutionPolicy.allCases == [
            .continuous,
            .single_step,
        ] else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        guard case .interrupted(let captured) = state,
              captured.point.path == "root.sequence[0]",
              captured.point.callID == "first",
              captured.point.attemptNumber == 1,
              case .policy(.single_step) = captured.reason else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        return [
            .field(
                "continuous",
                ToolPlan.ExecutionPolicy.continuous.rawValue
            ),
            .field(
                "single-step",
                ToolPlan.ExecutionPolicy.single_step.rawValue
            ),
            .field(
                "interruption",
                "single_step"
            ),
        ]
    }

    static func runToolPlanSingleStepStart() async throws -> [TestDiagnostic] {
        let fixture = try makeFixture()
        let run = try await fixture.executor.start(
            fixture.plan,
            runID: "single-step-start",
            executionPolicy: .single_step
        )

        guard case .interrupted(let interruption) = run.state,
              interruption.point.path == "root.sequence[0]",
              interruption.point.callID == "prefix",
              interruption.point.attemptNumber == 1,
              case .policy(.single_step) = interruption.reason else {
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
                "interrupted"
            ),
            .field(
                "after",
                interruption.point.callID
            ),
            .field(
                "executed",
                await fixture.probe.invocationLog()
            ),
        ]
    }

    static func runToolPlanSingleStepResume() async throws -> [TestDiagnostic] {
        let fixture = try makeFixture()
        let first = ToolCall(
            id: "first",
            tool: ToolIdentifier(
                rawValue: "tool_plan_run_probe"
            ),
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "first"
                )
            )
        )
        let second = ToolCall(
            id: "second",
            tool: ToolIdentifier(
                rawValue: "tool_plan_run_probe"
            ),
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "second"
                )
            )
        )
        let third = ToolCall(
            id: "third",
            tool: ToolIdentifier(
                rawValue: "tool_plan_run_probe"
            ),
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "third"
                )
            )
        )
        let fourth = ToolCall(
            id: "fourth",
            tool: ToolIdentifier(
                rawValue: "tool_plan_run_probe"
            ),
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "fourth"
                )
            )
        )
        let plan = try ToolPlan(
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

        guard case .interrupted(let firstInterruption) = started.state,
              firstInterruption.point.path == "root.sequence[0]",
              firstInterruption.point.callID == "first",
              firstInterruption.point.attemptNumber == 1,
              case .policy(.single_step) = firstInterruption.reason else {
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

        guard case .interrupted(let secondInterruption) = stepped.state,
              secondInterruption.point.path == "root.sequence[1]",
              secondInterruption.point.callID == "second",
              secondInterruption.point.attemptNumber == 2,
              case .policy(.single_step) = secondInterruption.reason else {
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

        let terminalRun = try await fixture.executor.resume(
            stepped,
            executionPolicy: .continuous
        )

        guard case .terminal(.succeeded) = terminalRun.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            await fixture.probe.invocationLog(),
            "first,second,third,fourth",
            "continuous resume traverses success branch and batch without replay"
        )

        try Expect.equal(
            terminalRun.attempts.count,
            4,
            "single-step traversal records one attempt per authored call"
        )

        guard case .node(
            path: "root.sequence[1].onSuccess[0]",
            callID: "third"
        ) = terminalRun.attempts[2].scope,
              case .node(
                path: "root.sequence[2].batch[0]",
                callID: "fourth"
              ) = terminalRun.attempts[3].scope else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            terminalRun.revision,
            4,
            "each authored execution boundary advances run revision"
        )

        return [
            .field(
                "state",
                "terminal"
            ),
            .field(
                "stepped-after",
                secondInterruption.point.callID
            ),
            .field(
                "executed",
                await fixture.probe.invocationLog()
            ),
            .field(
                "revision",
                "\(terminalRun.revision)"
            ),
        ]
    }

    static func runToolPlanRetryAndResume() async throws -> [TestDiagnostic] {
        let fixture = try makeFixture()
        let initial = try await fixture.executor.start(
            fixture.plan,
            runID: "retry-resume-run"
        )

        guard case .interrupted(let initialInterruption) = initial.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        guard case .failure = initialInterruption.reason else {
            throw AgenticExecutionFlowError.unexpectedInterruptionReason
        }

        try Expect.equal(
            initialInterruption.point.path,
            "root.sequence[1]",
            "initial failure path"
        )

        try Expect.equal(
            initialInterruption.point.callID,
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

        guard case .interrupted(let retryInterruption) = retried.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        guard case .continuation_required(let retryResolution) = retryInterruption.reason else {
            throw AgenticExecutionFlowError.unexpectedInterruptionReason
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

        guard case .terminal(.succeeded) = resumed.state else {
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
            ToolPlan.Run.self,
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
                "terminal"
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

    static func runToolPlanFailureEvidence() async throws -> [TestDiagnostic] {
        let fixture = try makeFailureEvidenceFixture(
            retrySafety: .unsafe
        )
        let run = try await fixture.executor.start(
            fixture.plan,
            runID: "failure-evidence-run"
        )

        guard case .interrupted(let interruption) = run.state,
              case .failure(let failure) = interruption.reason,
              let toolFailure = failure.toolFailure,
              let recovery = failure.recovery,
              let errorDescription = failure.errorDescription,
              !errorDescription.isEmpty else {
            throw AgenticExecutionFlowError.unexpectedFailureEvidence
        }

        try Expect.equal(
            interruption.point.path,
            "root",
            "failure interruption retains exact plan path"
        )
        try Expect.equal(
            interruption.point.callID,
            "failure-evidence",
            "failure interruption retains exact call id"
        )
        try Expect.equal(
            toolFailure.tool.rawValue,
            "tool_plan_failure_evidence_probe",
            "run failure retains typed tool identifier"
        )
        try Expect.equal(
            toolFailure.toolCallID,
            "failure-evidence",
            "run failure retains typed tool call id"
        )
        try Expect.equal(
            toolFailure.phase,
            .call,
            "run failure retains typed tool phase"
        )
        try Expect.equal(
            recovery.state.effect,
            .applied,
            "run failure retains recovery effect state"
        )
        try Expect.equal(
            recovery.state.retry,
            .unsafe,
            "run failure retains recovery retry safety"
        )
        try Expect.equal(
            recovery.outcome,
            .propagated,
            "run failure retains propagated mechanical recovery evidence"
        )
        try Expect.equal(
            await fixture.probe.invocationCount(),
            1,
            "failure evidence fixture executes exactly once"
        )

        return [
            .field(
                "state",
                "interrupted"
            ),
            .field(
                "phase",
                toolFailure.phase.rawValue
            ),
            .field(
                "recovery",
                recovery.outcome.rawValue
            ),
            .field(
                "retry-safety",
                recovery.state.retry.rawValue
            ),
        ]
    }

    static func runToolPlanRetrySafety() async throws -> [TestDiagnostic] {
        let retrySafeties: [Recovery.RetrySafety] = [
            .requires_reconciliation,
            .unsafe,
        ]
        var blocked: [String] = []

        for retrySafety in retrySafeties {
            let fixture = try makeFailureEvidenceFixture(
                retrySafety: retrySafety
            )
            let run = try await fixture.executor.start(
                fixture.plan,
                runID: "retry-safety-\(retrySafety.rawValue)"
            )

            guard case .interrupted(let interruption) = run.state,
                  case .failure(let failure) = interruption.reason,
                  failure.recovery?.state.retry == retrySafety else {
                throw AgenticExecutionFlowError.unexpectedFailureEvidence
            }

            do {
                _ = try await fixture.executor.retry(
                    run
                )
                throw AgenticExecutionFlowError.unexpectedRetry
            } catch let error as ToolPlan.Run.Error {
                guard case .retryNotSafe(let captured) = error,
                      captured == retrySafety else {
                    throw AgenticExecutionFlowError.unexpectedRetrySafety
                }
            }

            try Expect.equal(
                await fixture.probe.invocationCount(),
                1,
                "unsafe workflow retry must be rejected before tool replay"
            )

            blocked.append(
                retrySafety.rawValue
            )
        }

        return [
            .field(
                "blocked",
                blocked.joined(
                    separator: ","
                )
            ),
            .field(
                "replays",
                "0"
            ),
        ]
    }

    static func runToolPlanFailureBranchRetryResume() async throws -> [TestDiagnostic] {
        let fixture = try makeFixture()
        let prefix = ToolCall(
            id: "failure-branch-prefix",
            tool: ToolIdentifier(
                rawValue: "tool_plan_run_probe"
            ),
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "prefix"
                )
            )
        )
        let repair = ToolCall(
            id: "failure-branch-repair",
            tool: ToolIdentifier(
                rawValue: "tool_plan_run_probe"
            ),
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "repair"
                )
            )
        )
        let branchFix = ToolCall(
            id: "failure-branch-fix",
            tool: ToolIdentifier(
                rawValue: "tool_plan_run_probe"
            ),
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "branch-fix"
                )
            )
        )
        let suffix = ToolCall(
            id: "failure-branch-suffix",
            tool: ToolIdentifier(
                rawValue: "tool_plan_run_probe"
            ),
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "suffix"
                )
            )
        )
        let plan = try ToolPlan(
            id: "failure-branch-retry-resume-probe",
            root: .sequence(
                [
                    .call(prefix),
                    .call(
                        repair,
                        onFailure: [
                            .call(
                                branchFix
                            ),
                        ]
                    ),
                    .call(suffix),
                ]
            )
        )

        let initial = try await fixture.executor.start(
            plan,
            runID: "failure-branch-retry-resume"
        )

        guard case .interrupted(let initialInterruption) = initial.state,
              initialInterruption.point.path == "root.sequence[1]",
              initialInterruption.point.callID == "failure-branch-repair",
              let initialAttempt = initial.attempts.first else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        guard initialAttempt.result.records.contains(
            where: {
                $0.path == "root.sequence[1].onFailure[0]"
                    && $0.call.id == "failure-branch-fix"
                    && $0.outcome == .succeeded
            }
        ),
        !initialAttempt.result.records.contains(
            where: {
                $0.path.contains(
                    ".onFailure.sequence["
                )
            }
        ) else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            await fixture.probe.invocationLog(),
            "prefix,repair,branch-fix",
            "selected failure branch executes before parent interruption"
        )

        let retried = try await fixture.executor.retry(
            initial
        )

        guard case .interrupted(let retryInterruption) = retried.state,
              case .continuation_required(let resolution) = retryInterruption.reason else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            resolution.path,
            "root.sequence[1]",
            "retry resolves only the failed parent call"
        )
        try Expect.equal(
            await fixture.probe.invocationLog(),
            "prefix,repair,branch-fix,repair",
            "retry does not replay the authored failure branch"
        )

        let resumed = try await fixture.executor.resume(
            retried
        )

        guard case .terminal(.succeeded) = resumed.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            await fixture.probe.invocationLog(),
            "prefix,repair,branch-fix,repair,suffix",
            "resume executes the untouched suffix exactly once"
        )
        try Expect.equal(
            resumed.resolutions.map(\.path),
            [
                "root.sequence[1]",
            ],
            "failure-branch recovery records no resolution for the untouched suffix"
        )

        guard !resumed.resolutions.contains(
            where: {
                $0.path == "root.sequence[2]"
            }
        ) else {
            throw AgenticExecutionFlowError.unexpectedResolution
        }

        return [
            .field(
                "branch-path",
                "root.sequence[1].onFailure[0]"
            ),
            .field(
                "resolution-path",
                resolution.path
            ),
            .field(
                "executed",
                await fixture.probe.invocationLog()
            ),
        ]
    }

    static func runToolPlanSkipAndResume() async throws -> [TestDiagnostic] {
        let fixture = try makeFixture()
        let initial = try await fixture.executor.start(
            fixture.plan,
            runID: "skip-resume-run"
        )

        guard case .interrupted = initial.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        let skipped = try fixture.executor.skip(
            initial
        )

        guard case .interrupted(let skippedInterruption) = skipped.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        guard case .continuation_required(let skipResolution) = skippedInterruption.reason else {
            throw AgenticExecutionFlowError.unexpectedInterruptionReason
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

        guard case .terminal(.succeeded) = resumed.state else {
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
                "terminal"
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

    static func runToolPlanApprovalSkip() async throws -> [TestDiagnostic] {
        let probe = PlanRunProbe()
        let tool = PlanRunProbeTool<
            PlanRunApprovalSkipIdentity
        >(
            probe: probe
        )
        let invoker = ToolInvoker(
            registry: try ToolRegistry {
                tool
            },
            policy: ToolExecutionPolicy(
                autonomyMode: .auto_observe
            )
        )
        let executor = ToolPlan.RunExecutor(
            invoker: invoker
        )
        let plan = try ToolPlan(
            id: "approval-skip-plan",
            root: .sequence(
                [
                    .call(
                        ToolCall(
                            id: "approval-prefix",
                            tool: ToolIdentifier(
                                rawValue: "tool_plan_approval_skip_probe"
                            ),
                            input: try JSONToolBridge.encode(
                                RunProbeInput(
                                    marker: "approval-prefix"
                                )
                            )
                        )
                    ),
                    .call(
                        ToolCall(
                            id: "approval-skip",
                            tool: ToolIdentifier(
                                rawValue: "tool_plan_approval_skip_probe"
                            ),
                            input: try JSONToolBridge.encode(
                                RunProbeInput(
                                    marker: "approval-skip"
                                )
                            )
                        )
                    ),
                    .call(
                        ToolCall(
                            id: "approval-suffix",
                            tool: ToolIdentifier(
                                rawValue: "tool_plan_approval_skip_probe"
                            ),
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

        guard case .terminal(.succeeded) = run.state else {
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
                "terminal"
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

private actor PlanRunFailureEvidenceProbe {
    private var invocations = 0

    func invoke(
        _ input: RunProbeInput
    ) throws -> RunProbeInput {
        invocations += 1
        throw RunProbeError.failureEvidence
    }

    func invocationCount() -> Int {
        invocations
    }
}

private struct PlanRunFailureEvidenceTool: Tool {
    typealias Input = RunProbeInput
    typealias Output = RunProbeInput

    static let definition = ToolDefinition(
        identifier: "tool_plan_failure_evidence_probe",
        purpose:
            "Produces classified ToolPlan failure evidence for run hardening tests.",
        risk: .observe
    )

    let probe: PlanRunFailureEvidenceProbe
    let retrySafety: Recovery.RetrySafety

    func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        try await probe.invoke(
            input
        )
    }

    func classify(
        _ error: any Error,
        phase: ToolCall.Phase,
        input _: Input?
    ) -> Recovery.Incident? {
        guard phase == .call,
              error is RunProbeError else {
            return nil
        }

        let kind: Recovery.Kind
        let effectState: Recovery.EffectState

        switch retrySafety {
        case .safe:
            kind = .transport_transient
            effectState = .none

        case .requires_reconciliation:
            kind = .outcome_unknown
            effectState = .unknown

        case .unsafe:
            kind = .invariant_violation
            effectState = .applied
        }

        return Recovery.Incident(
            kind: kind,
            stage: .execution,
            effectState: effectState,
            retrySafety: retrySafety,
            scope: .init(
                kind: .tool,
                identifier:
                    Self.definition.identifier.rawValue
            ),
            message:
                "Synthetic ToolPlan run failure evidence."
        )
    }
}

private extension AgenticExecutionFlowTesting {
    struct FailureEvidenceFixture {
        let executor: ToolPlan.RunExecutor
        let plan: ToolPlan
        let probe: PlanRunFailureEvidenceProbe
    }

    static func makeFailureEvidenceFixture(
        retrySafety: Recovery.RetrySafety
    ) throws -> FailureEvidenceFixture {
        let probe = PlanRunFailureEvidenceProbe()
        let tool = PlanRunFailureEvidenceTool(
            probe: probe,
            retrySafety: retrySafety
        )
        let invoker = ToolInvoker(
            registry: try ToolRegistry {
                tool
            },
            policy: ToolExecutionPolicy(
                autonomyMode: .auto_observe
            )
        )
        let call = ToolCall(
            id: "failure-evidence",
            tool: ToolIdentifier(
                rawValue:
                    "tool_plan_failure_evidence_probe"
            ),
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: retrySafety.rawValue
                )
            )
        )
        let plan = try ToolPlan(
            id: "failure-evidence-plan",
            root: .call(
                call
            )
        )

        return FailureEvidenceFixture(
            executor: ToolPlan.RunExecutor(
                invoker: invoker
            ),
            plan: plan,
            probe: probe
        )
    }
}

private extension AgenticExecutionFlowTesting {
    struct Fixture {
        let executor: ToolPlan.RunExecutor
        let plan: ToolPlan
        let probe: PlanRunProbe
    }

    static func makeFixture() throws -> Fixture {
        let probe = PlanRunProbe()
        let tool = PlanRunProbeTool<
            PlanRunDefaultIdentity
        >(
            probe: probe
        )
        let invoker = ToolInvoker(
            registry: try ToolRegistry {
                tool
            },
            policy: ToolExecutionPolicy(
                autonomyMode: .auto_observe
            )
        )
        let prefix = ToolCall(
            id: "prefix",
            tool: ToolIdentifier(
                rawValue: "tool_plan_run_probe"
            ),
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "prefix"
                )
            )
        )
        let repair = ToolCall(
            id: "repair",
            tool: ToolIdentifier(
                rawValue: "tool_plan_run_probe"
            ),
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "repair"
                )
            )
        )
        let suffix = ToolCall(
            id: "suffix",
            tool: ToolIdentifier(
                rawValue: "tool_plan_run_probe"
            ),
            input: try JSONToolBridge.encode(
                RunProbeInput(
                    marker: "suffix"
                )
            )
        )
        let plan = try ToolPlan(
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
            executor: ToolPlan.RunExecutor(
                invoker: invoker
            ),
            plan: plan,
            probe: probe
        )
    }
}

private protocol PlanRunProbeIdentity {
    static var definition: ToolDefinition { get }
}

private enum PlanRunDefaultIdentity:
    PlanRunProbeIdentity
{
    static let definition = ToolDefinition(
        identifier: "tool_plan_run_probe",
        purpose:
            "Records execution order and fails the repair marker once.",
        risk: .observe
    )
}

private enum PlanRunApprovalSkipIdentity:
    PlanRunProbeIdentity
{
    static let definition = ToolDefinition(
        identifier: "tool_plan_approval_skip_probe",
        purpose:
            "Records ToolPlan execution while one reviewed call is explicitly skipped.",
        risk: .boundedmutate
    )
}

private struct PlanRunProbeTool<
    Identity: PlanRunProbeIdentity
>: Tool {
    typealias Input = RunProbeInput
    typealias Output = RunProbeInput

    static var definition: ToolDefinition {
        Identity.definition
    }

    let probe: PlanRunProbe

    func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        try await probe.invoke(
            input
        )
    }
}

private actor PlanRunProbe {
    private var invocations: [String] = []
    private var repairFailed = false

    func invoke(
        _ input: RunProbeInput
    ) throws -> RunProbeInput {
        invocations.append(
            input.marker
        )

        if input.marker == "repair",
           !repairFailed
        {
            repairFailed = true
            throw RunProbeError.firstRepairAttempt
        }

        return input
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
    JSONSchemaProviding,
    Hashable
{
    let marker: String

    static var jsonschema: JSONSchema {
        JSONSchema.object {
            JSONSchema.string(
                "marker",
                required: true
            )
        }
    }
}

private enum RunProbeError: Error {
    case firstRepairAttempt
    case failureEvidence
}

private enum AgenticExecutionFlowError: Error {
    case unexpectedRunState
    case unexpectedInterruptionReason
    case unexpectedResolution
    case unexpectedFailureEvidence
    case unexpectedRetry
    case unexpectedRetrySafety
}
