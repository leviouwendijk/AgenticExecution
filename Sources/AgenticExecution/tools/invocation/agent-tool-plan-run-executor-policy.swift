import Agentic
import Foundation

public extension AgentToolPlanRunExecutor {
    func start(
        _ plan: AgentToolPlan,
        runID: String = UUID().uuidString,
        relationship: AgentToolPlanRunRelationship = .root,
        executionPolicy: AgentToolPlanExecutionPolicy,
        context: AgentToolExecutionContext = .init(),
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> AgentToolPlanRun {
        switch executionPolicy {
        case .continuous:
            return try await start(
                plan,
                runID: runID,
                relationship: relationship,
                context: context,
                approvalHandler: approvalHandler
            )

        case .single_step:
            return try await startSingleStep(
                plan,
                runID: runID,
                relationship: relationship,
                context: context,
                approvalHandler: approvalHandler
            )
        }
    }

    func resume(
        _ run: AgentToolPlanRun,
        executionPolicy: AgentToolPlanExecutionPolicy,
        context: AgentToolExecutionContext = .init(),
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> AgentToolPlanRun {
        guard case .paused(let pause) = run.state else {
            throw AgentToolPlanRunError.runNotPaused
        }

        switch executionPolicy {
        case .continuous:
            return try await resumePausedContinuously(
                run,
                pause: pause,
                context: context,
                approvalHandler: approvalHandler
            )

        case .single_step:
            return try await resumePausedSingleStep(
                run,
                pause: pause,
                context: context,
                approvalHandler: approvalHandler
            )
        }
    }
}

private extension AgentToolPlanRunExecutor {
    func startSingleStep(
        _ plan: AgentToolPlan,
        runID: String,
        relationship: AgentToolPlanRunRelationship,
        context: AgentToolExecutionContext,
        approvalHandler: (any ToolApprovalHandler)?
    ) async throws -> AgentToolPlanRun {
        try plan.validate()

        let steps = try plan.root.serialSingleSteps(
            path: "root"
        )

        guard let step = steps.first else {
            return try await start(
                plan,
                runID: runID,
                relationship: relationship,
                context: context,
                approvalHandler: approvalHandler
            )
        }

        let attemptNumber = 1
        let isolatedPlan = AgentToolPlan(
            id: "\(plan.id).single-step.\(attemptNumber)",
            root: step.node,
            guidelineRelations: plan.guidelineRelations
        )
        let isolatedRun = try await start(
            isolatedPlan,
            runID: "\(runID).single-step.\(attemptNumber)",
            relationship: relationship,
            context: context,
            approvalHandler: approvalHandler
        )

        guard let isolatedResult = isolatedRun.latestResult else {
            throw AgentToolPlanRunError.unsupportedContinuation(
                step.path
            )
        }

        let result = isolatedResult.remapped(
            planID: plan.id,
            beneath: step.path
        )
        let attempt = AgentToolPlanAttempt(
            number: attemptNumber,
            scope: .node(
                path: step.path,
                callID: step.call.id
            ),
            result: result
        )
        let state = singleStepState(
            from: isolatedRun.state,
            step: step,
            attemptNumber: attemptNumber,
            hasContinuation: steps.count > 1
        )

        return AgentToolPlanRun(
            id: runID,
            plan: plan,
            relationship: relationship,
            attempts: [
                attempt,
            ],
            resolutions: [],
            revision: 1,
            state: state
        )
    }

    func singleStepState(
        from state: AgentToolPlanRunState,
        step: AgentToolPlanSingleStep,
        attemptNumber: Int,
        hasContinuation: Bool
    ) -> AgentToolPlanRunState {
        switch state {
        case .completed:
            guard hasContinuation else {
                return .completed
            }

            return .paused(
                AgentToolPlanPause(
                    afterPath: step.path,
                    afterCallID: step.call.id,
                    attemptNumber: attemptNumber,
                    reason: .single_step
                )
            )

        case .paused(let pause):
            return .paused(
                AgentToolPlanPause(
                    afterPath: step.path,
                    afterCallID: step.call.id,
                    attemptNumber: attemptNumber,
                    reason: pause.reason
                )
            )

        case .suspended(let suspension):
            return .suspended(
                AgentToolPlanSuspension(
                    path: suspension.path.remapped(
                        beneath: step.path
                    ),
                    callID: suspension.callID,
                    attemptNumber: attemptNumber,
                    reason: suspension.reason
                )
            )

        case .stopped(let outcome):
            return .stopped(
                outcome
            )
        }
    }
}

private extension AgentToolPlanRunExecutor {
    func resumePausedSingleStep(
        _ run: AgentToolPlanRun,
        pause: AgentToolPlanPause,
        context: AgentToolExecutionContext,
        approvalHandler: (any ToolApprovalHandler)?
    ) async throws -> AgentToolPlanRun {
        let steps = try run.plan.root.serialSingleSteps(
            path: "root"
        )

        guard let currentIndex = steps.firstIndex(
            where: { step in
                step.path == pause.afterPath
                    && step.call.id == pause.afterCallID
            }
        ) else {
            throw AgentToolPlanRunError.missingPausedCall(
                pause.afterCallID
            )
        }

        let nextIndex = currentIndex + 1
        let revision = run.revision + 1

        guard steps.indices.contains(nextIndex) else {
            return AgentToolPlanRun(
                id: run.id,
                plan: run.plan,
                relationship: run.relationship,
                attempts: run.attempts,
                resolutions: run.resolutions,
                revision: revision,
                state: .completed
            )
        }

        let step = steps[nextIndex]
        let attemptNumber = run.attempts.count + 1
        let isolatedPlan = AgentToolPlan(
            id: "\(run.plan.id).single-step.\(attemptNumber)",
            root: step.node,
            guidelineRelations: run.plan.guidelineRelations
        )
        let isolatedRun = try await start(
            isolatedPlan,
            runID: "\(run.id).single-step.\(attemptNumber)",
            relationship: run.relationship,
            context: context,
            approvalHandler: approvalHandler
        )

        guard let isolatedResult = isolatedRun.latestResult else {
            throw AgentToolPlanRunError.unsupportedContinuation(
                step.path
            )
        }

        let result = isolatedResult.remapped(
            planID: run.plan.id,
            beneath: step.path
        )
        let attempt = AgentToolPlanAttempt(
            number: attemptNumber,
            scope: .node(
                path: step.path,
                callID: step.call.id
            ),
            result: result
        )
        let state = singleStepState(
            from: isolatedRun.state,
            step: step,
            attemptNumber: attemptNumber,
            hasContinuation: nextIndex < steps.count - 1
        )

        return AgentToolPlanRun(
            id: run.id,
            plan: run.plan,
            relationship: run.relationship,
            attempts: run.attempts + [attempt],
            resolutions: run.resolutions,
            revision: revision,
            state: state
        )
    }

    func resumePausedContinuously(
        _ run: AgentToolPlanRun,
        pause: AgentToolPlanPause,
        context: AgentToolExecutionContext,
        approvalHandler: (any ToolApprovalHandler)?
    ) async throws -> AgentToolPlanRun {
        try await resumeContinuation(
            run,
            afterPath: pause.afterPath,
            afterCallID: pause.afterCallID,
            context: context,
            approvalHandler: approvalHandler
        )
    }
}

private struct AgentToolPlanSingleStep:
    Sendable
{
    let path: String
    let call: AgentToolCall
    let node: AgentToolPlanNode
}

private extension AgentToolPlanNode {
    func serialSingleSteps(
        path: String
    ) throws -> [AgentToolPlanSingleStep] {
        switch self {
        case .call(
            let call,
            let execution,
            let onSuccess,
            let onFailure,
            let onDenied
        ):
            guard onSuccess.isEmpty,
                  onFailure.isEmpty,
                  onDenied.isEmpty else {
                throw AgentToolPlanRunError.unsupportedContinuation(
                    path
                )
            }

            return [
                AgentToolPlanSingleStep(
                    path: path,
                    call: call,
                    node: .call(
                        call,
                        execution: execution
                    )
                ),
            ]

        case .sequence(let children):
            var steps: [AgentToolPlanSingleStep] = []

            for (
                index,
                child
            ) in children.enumerated() {
                steps.append(
                    contentsOf: try child.serialSingleSteps(
                        path: "\(path).sequence[\(index)]"
                    )
                )
            }

            return steps

        case .batch:
            throw AgentToolPlanRunError.unsupportedContinuation(
                path
            )
        }
    }
}

private extension AgentToolPlanResult {
    func remapped(
        planID: String,
        beneath path: String
    ) -> AgentToolPlanResult {
        AgentToolPlanResult(
            planID: planID,
            outcome: outcome,
            records: records.map { record in
                AgentToolPlanRecord(
                    path: record.path.remapped(
                        beneath: path
                    ),
                    call: record.call,
                    outcome: record.outcome,
                    invocation: record.invocation,
                    errorDescription: record.errorDescription,
                    skipReason: record.skipReason
                )
            }
        )
    }
}

private extension String {
    func remapped(
        beneath path: String
    ) -> String {
        guard self != "root" else {
            return path
        }

        guard hasPrefix(
            "root."
        ) else {
            return self
        }

        return path
            + String(
                dropFirst(
                    "root".count
                )
            )
    }
}
