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
            var current = run

            while case .paused = current.state {
                current = try await resume(
                    current,
                    executionPolicy: .single_step,
                    context: context,
                    approvalHandler: approvalHandler
                )
            }

            return current

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

        let initialTraversal = plan.root.singleStepTraversal(
            path: "root",
            outcomesByPath: [:]
        )

        guard case .next(let step) = initialTraversal else {
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
        let attempts = [
            attempt,
        ]
        let traversal = plan.root.singleStepTraversal(
            path: "root",
            outcomesByPath: AgentToolPlanSingleStepHistory
                .outcomesByPath(
                    attempts: attempts
                )
        )
        let state = singleStepState(
            from: isolatedRun.state,
            step: step,
            attemptNumber: attemptNumber,
            traversal: traversal
        )

        return AgentToolPlanRun(
            id: runID,
            plan: plan,
            relationship: relationship,
            attempts: attempts,
            resolutions: [],
            revision: 1,
            state: state
        )
    }

    func singleStepState(
        from state: AgentToolPlanRunState,
        step: AgentToolPlanSingleStep,
        attemptNumber: Int,
        traversal: AgentToolPlanSingleStepTraversal
    ) -> AgentToolPlanRunState {
        switch state {
        case .completed:
            return agentToolPlanSingleStepParentState(
                traversal: traversal,
                after: step,
                attemptNumber: attemptNumber
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

        case .stopped:
            return agentToolPlanSingleStepParentState(
                traversal: traversal,
                after: step,
                attemptNumber: attemptNumber
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
        let outcomesByPath =
            AgentToolPlanSingleStepHistory.outcomesByPath(
                attempts: run.attempts,
                resolutions: run.resolutions
            )

        guard AgentToolPlanSingleStepHistory.containsRecordedCall(
            path: pause.afterPath,
            callID: pause.afterCallID,
            attempts: run.attempts,
            resolutions: run.resolutions
        ) else {
            throw AgentToolPlanRunError.missingPausedCall(
                pause.afterCallID
            )
        }

        let traversal = run.plan.root.singleStepTraversal(
            path: "root",
            outcomesByPath: outcomesByPath
        )
        let revision = run.revision + 1

        guard case .next(let step) = traversal else {
            let state: AgentToolPlanRunState

            switch traversal {
            case .complete(.succeeded):
                state = .completed

            case .complete(let outcome):
                state = .stopped(
                    outcome
                )

            case .next:
                preconditionFailure(
                    "Traversal changed after matching .next."
                )
            }

            return AgentToolPlanRun(
                id: run.id,
                plan: run.plan,
                relationship: run.relationship,
                attempts: run.attempts,
                resolutions: run.resolutions,
                revision: revision,
                state: state
            )
        }
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
        let attempts = run.attempts + [
            attempt,
        ]
        let nextTraversal = run.plan.root.singleStepTraversal(
            path: "root",
            outcomesByPath: AgentToolPlanSingleStepHistory
                .outcomesByPath(
                    attempts: attempts,
                    resolutions: run.resolutions
                )
        )
        let state = singleStepState(
            from: isolatedRun.state,
            step: step,
            attemptNumber: attemptNumber,
            traversal: nextTraversal
        )

        return AgentToolPlanRun(
            id: run.id,
            plan: run.plan,
            relationship: run.relationship,
            attempts: attempts,
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

struct AgentToolPlanSingleStep:
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
                    toolFailure: record.toolFailure,
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