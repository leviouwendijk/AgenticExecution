import Agentic
import Foundation
import Workspace

/// Durable ToolPlan orchestration above ToolPlanExecutor.
///
/// ToolPlanExecutor remains the authority for governed node execution. This
/// layer records attempts and workflow resolutions, derives terminal versus
/// interrupted run state, and asks ToolPlan.Navigator for structural lookup,
/// remapping, and continuation.
public extension ToolPlan {
    struct RunExecutor:
        Sendable
    {
        public let invoker: ToolInvoker

        public init(
            invoker: ToolInvoker
        ) {
            self.invoker = invoker
        }

        public func start(
            _ plan: ToolPlan,
            runID: String = UUID().uuidString,
            relationship: ToolPlan.Run.Relationship = .root,
            workspace: WorkspaceContext? = nil,
            guidelineRelations: [AgentGuidelineRelation] = [],
            approvalHandler: (any ToolApprovalHandler)? = nil
        ) async throws -> ToolPlan.Run {
            let result = try await planExecutor.execute(
                plan,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )
            let attemptNumber = 1

            return ToolPlan.Run(
                id: runID,
                plan: plan,
                relationship: relationship,
                attempts: [
                    ToolPlan.Run.Attempt(
                        number: attemptNumber,
                        scope: .plan,
                        result: result
                    ),
                ],
                revision: 1,
                state: state(
                    for: result,
                    attemptNumber: attemptNumber
                )
            )
        }

        /// Retry exactly the currently interrupted node.
        ///
        /// The successful prefix and untouched parent suffix are never replayed.
        /// Structured Recovery evidence is consulted before replaying a failed
        /// operation when that evidence is available.
        public func retry(
            _ run: ToolPlan.Run,
            workspace: WorkspaceContext? = nil,
            guidelineRelations: [AgentGuidelineRelation] = [],
            approvalHandler: (any ToolApprovalHandler)? = nil
        ) async throws -> ToolPlan.Run {
            let interruption = try unresolvedExecutionInterruption(
                run
            )

            try requireRetryAllowed(
                interruption
            )

            let navigator = ToolPlan.Navigator(
                run.plan
            )

            guard let node = navigator.node(
                containingCallID: interruption.point.callID
            ) else {
                throw ToolPlan.Run.Error.missingInterruptedCall(
                    interruption.point.callID
                )
            }

            let attemptNumber = run.attempts.count + 1
            let retryPlan = try ToolPlan(
                id: "\(run.plan.id).retry.\(attemptNumber)",
                root: node,
                guidelines: run.plan.guidelines
            )
            let rawResult = try await planExecutor.execute(
                retryPlan,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )
            let result = navigator.remap(
                rawResult,
                beneath: interruption.point.path
            )
            let revision = run.revision + 1
            let attempt = ToolPlan.Run.Attempt(
                number: attemptNumber,
                scope: .node(
                    path: interruption.point.path,
                    callID: interruption.point.callID
                ),
                result: result
            )

            var resolutions = run.resolutions
            let nextState: ToolPlan.Run.State

            if result.outcome == .succeeded {
                let resolutionKind: ToolPlan.Run.Resolution.Kind

                if result.records.contains(
                    where: { record in
                        record.path == interruption.point.path
                            && record.outcome == .skipped
                    }
                ) {
                    resolutionKind = .skipped
                } else {
                    resolutionKind = .retried(
                        attemptNumber: attemptNumber
                    )
                }

                let resolution = ToolPlan.Run.Resolution(
                    revision: revision,
                    path: interruption.point.path,
                    callID: interruption.point.callID,
                    kind: resolutionKind
                )

                resolutions.append(
                    resolution
                )

                nextState = resolvedState(
                    plan: run.plan,
                    interruption: interruption,
                    resolution: resolution,
                    attemptNumber: attemptNumber
                )
            } else {
                nextState = state(
                    for: result,
                    attemptNumber: attemptNumber
                )
            }

            return ToolPlan.Run(
                id: run.id,
                plan: run.plan,
                relationship: run.relationship,
                attempts: run.attempts + [attempt],
                resolutions: resolutions,
                revision: revision,
                state: nextState
            )
        }

        /// Resolve the interrupted node without executing it again.
        public func skip(
            _ run: ToolPlan.Run
        ) throws -> ToolPlan.Run {
            let interruption = try unresolvedExecutionInterruption(
                run
            )
            let revision = run.revision + 1
            let resolution = ToolPlan.Run.Resolution(
                revision: revision,
                path: interruption.point.path,
                callID: interruption.point.callID,
                kind: .skipped
            )

            return ToolPlan.Run(
                id: run.id,
                plan: run.plan,
                relationship: run.relationship,
                attempts: run.attempts,
                resolutions: run.resolutions + [resolution],
                revision: revision,
                state: resolvedState(
                    plan: run.plan,
                    interruption: interruption,
                    resolution: resolution,
                    attemptNumber: interruption.point.attemptNumber
                )
            )
        }

        /// Resume only the untouched serial continuation after a resolved node.
        public func resume(
            _ run: ToolPlan.Run,
            workspace: WorkspaceContext? = nil,
            guidelineRelations: [AgentGuidelineRelation] = [],
            approvalHandler: (any ToolApprovalHandler)? = nil
        ) async throws -> ToolPlan.Run {
            guard case .interrupted(let interruption) = run.state else {
                throw ToolPlan.Run.Error.runNotInterrupted
            }

            guard case .continuation_required = interruption.reason else {
                throw ToolPlan.Run.Error.interruptionNotResolved
            }

            return try await resumeContinuation(
                run,
                afterPath: interruption.point.path,
                afterCallID: interruption.point.callID,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )
        }

        func resumeContinuation(
            _ run: ToolPlan.Run,
            afterPath: String,
            afterCallID: String,
            workspace: WorkspaceContext?,
            guidelineRelations: [AgentGuidelineRelation],
            approvalHandler: (any ToolApprovalHandler)?
        ) async throws -> ToolPlan.Run {
            let navigator = ToolPlan.Navigator(
                run.plan
            )

            guard let continuation = navigator.sequenceContinuation(
                afterCallID: afterCallID
            ) else {
                throw ToolPlan.Run.Error.unsupportedContinuation(
                    afterPath
                )
            }

            let revision = run.revision + 1

            guard !continuation.isEmpty else {
                return ToolPlan.Run(
                    id: run.id,
                    plan: run.plan,
                    relationship: run.relationship,
                    attempts: run.attempts,
                    resolutions: run.resolutions,
                    revision: revision,
                    state: .terminal(
                        .succeeded
                    )
                )
            }

            let attemptNumber = run.attempts.count + 1
            let result = try await executeContinuation(
                continuation,
                plan: run.plan,
                attemptNumber: attemptNumber,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )
            let attempt = ToolPlan.Run.Attempt(
                number: attemptNumber,
                scope: .continuation(
                    afterPath: afterPath
                ),
                result: result
            )

            return ToolPlan.Run(
                id: run.id,
                plan: run.plan,
                relationship: run.relationship,
                attempts: run.attempts + [attempt],
                resolutions: run.resolutions,
                revision: revision,
                state: state(
                    for: result,
                    attemptNumber: attemptNumber
                )
            )
        }
    }
}

private extension ToolPlan.RunExecutor {
    var planExecutor: ToolPlanExecutor {
        ToolPlanExecutor(
            invoker: invoker
        )
    }

    func unresolvedExecutionInterruption(
        _ run: ToolPlan.Run
    ) throws -> ToolPlan.Run.Interruption {
        guard case .interrupted(let interruption) = run.state else {
            throw ToolPlan.Run.Error.runNotInterrupted
        }

        switch interruption.reason {
        case .failure,
             .human_review:
            return interruption

        case .continuation_required:
            throw ToolPlan.Run.Error.interruptionAlreadyResolved

        case .policy:
            throw ToolPlan.Run.Error.runNotInterrupted
        }
    }

    func requireRetryAllowed(
        _ interruption: ToolPlan.Run.Interruption
    ) throws {
        guard case .failure(let failure) = interruption.reason,
              let recovery = failure.recovery
        else {
            return
        }

        guard recovery.state.retry == .safe else {
            throw ToolPlan.Run.Error.retryNotSafe(
                recovery.state.retry
            )
        }
    }

    func state(
        for result: ToolPlan.Result,
        attemptNumber: Int
    ) -> ToolPlan.Run.State {
        switch result.outcome {
        case .succeeded:
            return .terminal(
                .succeeded
            )

        case .failed:
            guard let record = result.records.last(
                where: {
                    $0.outcome == .failed
                }
            ) else {
                return .terminal(
                    .failed
                )
            }

            return .interrupted(
                ToolPlan.Run.Interruption(
                    point: ToolPlan.Run.Point(
                        path: record.path,
                        callID: record.call.id,
                        attemptNumber: attemptNumber
                    ),
                    reason: .failure(
                        ToolPlan.Run.Failure(
                            toolFailure: record.toolFailure,
                            recovery: record.invocation?.execution?.recovery,
                            errorDescription: record.errorDescription
                        )
                    )
                )
            )

        case .needs_human_review:
            guard let record = result.records.last(
                where: {
                    $0.outcome == .needs_human_review
                }
            ) else {
                return .terminal(
                    .needs_human_review
                )
            }

            return .interrupted(
                ToolPlan.Run.Interruption(
                    point: ToolPlan.Run.Point(
                        path: record.path,
                        callID: record.call.id,
                        attemptNumber: attemptNumber
                    ),
                    reason: .human_review
                )
            )

        case .denied,
             .skipped,
             .mixed:
            return .terminal(
                result.outcome
            )
        }
    }

    func resolvedState(
        plan: ToolPlan,
        interruption: ToolPlan.Run.Interruption,
        resolution: ToolPlan.Run.Resolution,
        attemptNumber: Int
    ) -> ToolPlan.Run.State {
        let continuation = ToolPlan.Navigator(
            plan
        ).sequenceContinuation(
            afterCallID: interruption.point.callID
        )

        if let continuation,
           continuation.isEmpty
        {
            return .terminal(
                .succeeded
            )
        }

        return .interrupted(
            ToolPlan.Run.Interruption(
                point: ToolPlan.Run.Point(
                    path: interruption.point.path,
                    callID: interruption.point.callID,
                    attemptNumber: attemptNumber
                ),
                reason: .continuation_required(
                    resolution
                )
            )
        )
    }

    func executeContinuation(
        _ continuation: [ToolPlan.Navigator.ContinuationStep],
        plan: ToolPlan,
        attemptNumber: Int,
        workspace: WorkspaceContext?,
        guidelineRelations: [AgentGuidelineRelation],
        approvalHandler: (any ToolApprovalHandler)?
    ) async throws -> ToolPlan.Result {
        let navigator = ToolPlan.Navigator(
            plan
        )
        var records: [ToolPlan.Record] = []

        for (
            index,
            step
        ) in continuation.enumerated() {
            let continuationPlan = try ToolPlan(
                id: "\(plan.id).resume.\(attemptNumber).\(index + 1)",
                root: step.node,
                guidelines: plan.guidelines
            )
            let rawResult = try await planExecutor.execute(
                continuationPlan,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )
            let result = navigator.remap(
                rawResult,
                beneath: step.path
            )

            records.append(
                contentsOf: result.records
            )

            guard result.outcome == .succeeded else {
                return ToolPlan.Result(
                    planID: "\(plan.id).resume.\(attemptNumber)",
                    outcome: result.outcome,
                    records: records
                )
            }
        }

        return ToolPlan.Result(
            planID: "\(plan.id).resume.\(attemptNumber)",
            outcome: .succeeded,
            records: records
        )
    }
}
