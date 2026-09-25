import Agentic
import Foundation
import Workspace

public extension ToolPlan.RunExecutor {
    func start(
        _ plan: ToolPlan,
        runID: String = UUID().uuidString,
        relationship: ToolPlan.Run.Relationship = .root,
        executionPolicy: ToolPlan.ExecutionPolicy,
        workspace: WorkspaceContext? = nil,
        guidelineRelations: [AgentGuidelineRelation] = [],
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> ToolPlan.Run {
        switch executionPolicy {
        case .continuous:
            return try await start(
                plan,
                runID: runID,
                relationship: relationship,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )

        case .single_step:
            return try await startSingleStep(
                plan,
                runID: runID,
                relationship: relationship,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )
        }
    }

    func resume(
        _ run: ToolPlan.Run,
        executionPolicy: ToolPlan.ExecutionPolicy,
        workspace: WorkspaceContext? = nil,
        guidelineRelations: [AgentGuidelineRelation] = [],
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> ToolPlan.Run {
        let interruption = try policyInterruption(
            run
        )

        switch executionPolicy {
        case .continuous:
            var current = run

            while isPolicyInterrupted(
                current
            ) {
                current = try await resume(
                    current,
                    executionPolicy: .single_step,
                    workspace: workspace,
                    guidelineRelations: guidelineRelations,
                    approvalHandler: approvalHandler
                )
            }

            return current

        case .single_step:
            return try await resumeSingleStep(
                run,
                interruption: interruption,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )
        }
    }
}

private extension ToolPlan.RunExecutor {
    func startSingleStep(
        _ plan: ToolPlan,
        runID: String,
        relationship: ToolPlan.Run.Relationship,
        workspace: WorkspaceContext?,
        guidelineRelations: [AgentGuidelineRelation],
        approvalHandler: (any ToolApprovalHandler)?
    ) async throws -> ToolPlan.Run {
        let navigator = ToolPlan.Navigator(
            plan
        )
        let initialTraversal = navigator.singleStepTraversal(
            outcomesByPath: [:]
        )

        guard case .next(let step) = initialTraversal else {
            return try await start(
                plan,
                runID: runID,
                relationship: relationship,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )
        }

        let attemptNumber = 1
        let isolatedPlan = try ToolPlan(
            id: "\(plan.id).single-step.\(attemptNumber)",
            root: step.node,
            guidelines: plan.guidelines
        )
        let isolatedRun = try await start(
            isolatedPlan,
            runID: "\(runID).single-step.\(attemptNumber)",
            relationship: relationship,
            workspace: workspace,
            guidelineRelations: guidelineRelations,
            approvalHandler: approvalHandler
        )

        guard let isolatedResult = isolatedRun.latestResult else {
            throw ToolPlan.Run.Error.unsupportedContinuation(
                step.path
            )
        }

        let result = navigator.remap(
            isolatedResult,
            planID: plan.id,
            beneath: step.path
        )
        let attempt = ToolPlan.Run.Attempt(
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
        let traversal = navigator.singleStepTraversal(
            outcomesByPath: ToolPlan.Run.History.outcomesByPath(
                attempts: attempts
            )
        )
        let state = singleStepState(
            from: isolatedRun.state,
            step: step,
            attemptNumber: attemptNumber,
            traversal: traversal
        )

        return ToolPlan.Run(
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
        from state: ToolPlan.Run.State,
        step: ToolPlan.Navigator.Step,
        attemptNumber: Int,
        traversal: ToolPlan.Navigator.Traversal
    ) -> ToolPlan.Run.State {
        switch state {
        case .terminal:
            return singleStepParentState(
                traversal: traversal,
                after: step,
                attemptNumber: attemptNumber
            )

        case .interrupted(let interruption):
            return .interrupted(
                ToolPlan.Run.Interruption(
                    point: ToolPlan.Run.Point(
                        path: ToolPlan.Navigator.remappedPath(
                            interruption.point.path,
                            beneath: step.path
                        ),
                        callID: interruption.point.callID,
                        attemptNumber: attemptNumber
                    ),
                    reason: interruption.reason
                )
            )
        }
    }

    func resumeSingleStep(
        _ run: ToolPlan.Run,
        interruption: ToolPlan.Run.Interruption,
        workspace: WorkspaceContext?,
        guidelineRelations: [AgentGuidelineRelation],
        approvalHandler: (any ToolApprovalHandler)?
    ) async throws -> ToolPlan.Run {
        let point = interruption.point
        let outcomesByPath = ToolPlan.Run.History.outcomesByPath(
            attempts: run.attempts,
            resolutions: run.resolutions
        )

        guard ToolPlan.Run.History.containsRecordedCall(
            path: point.path,
            callID: point.callID,
            attempts: run.attempts,
            resolutions: run.resolutions
        ) else {
            throw ToolPlan.Run.Error.missingPolicyBoundary(
                point.callID
            )
        }

        let navigator = ToolPlan.Navigator(
            run.plan
        )
        let traversal = navigator.singleStepTraversal(
            outcomesByPath: outcomesByPath
        )
        let revision = run.revision + 1

        guard case .next(let step) = traversal else {
            let state: ToolPlan.Run.State

            switch traversal {
            case .complete(let outcome):
                state = .terminal(
                    outcome
                )

            case .next:
                preconditionFailure(
                    "Traversal changed after matching .next."
                )
            }

            return ToolPlan.Run(
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
        let isolatedPlan = try ToolPlan(
            id: "\(run.plan.id).single-step.\(attemptNumber)",
            root: step.node,
            guidelines: run.plan.guidelines
        )
        let isolatedRun = try await start(
            isolatedPlan,
            runID: "\(run.id).single-step.\(attemptNumber)",
            relationship: run.relationship,
            workspace: workspace,
            guidelineRelations: guidelineRelations,
            approvalHandler: approvalHandler
        )

        guard let isolatedResult = isolatedRun.latestResult else {
            throw ToolPlan.Run.Error.unsupportedContinuation(
                step.path
            )
        }

        let result = navigator.remap(
            isolatedResult,
            planID: run.plan.id,
            beneath: step.path
        )
        let attempt = ToolPlan.Run.Attempt(
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
        let nextTraversal = navigator.singleStepTraversal(
            outcomesByPath: ToolPlan.Run.History.outcomesByPath(
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

        return ToolPlan.Run(
            id: run.id,
            plan: run.plan,
            relationship: run.relationship,
            attempts: attempts,
            resolutions: run.resolutions,
            revision: revision,
            state: state
        )
    }

    func policyInterruption(
        _ run: ToolPlan.Run
    ) throws -> ToolPlan.Run.Interruption {
        guard case .interrupted(let interruption) = run.state,
              case .policy = interruption.reason
        else {
            throw ToolPlan.Run.Error.runNotPolicyInterrupted
        }

        return interruption
    }

    func isPolicyInterrupted(
        _ run: ToolPlan.Run
    ) -> Bool {
        guard case .interrupted(let interruption) = run.state,
              case .policy = interruption.reason
        else {
            return false
        }

        return true
    }

    func singleStepParentState(
        traversal: ToolPlan.Navigator.Traversal,
        after step: ToolPlan.Navigator.Step,
        attemptNumber: Int
    ) -> ToolPlan.Run.State {
        switch traversal {
        case .next:
            return .interrupted(
                ToolPlan.Run.Interruption(
                    point: ToolPlan.Run.Point(
                        path: step.path,
                        callID: step.call.id,
                        attemptNumber: attemptNumber
                    ),
                    reason: .policy(
                        .single_step
                    )
                )
            )

        case .complete(let outcome):
            return .terminal(
                outcome
            )
        }
    }
}
