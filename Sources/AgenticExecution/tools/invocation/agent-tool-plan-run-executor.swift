import Agentic
import Foundation

public enum AgentToolPlanRunError:
    Error,
    Sendable,
    LocalizedError,
    Equatable
{
    case runNotSuspended
    case runNotPaused
    case suspensionAlreadyResolved
    case suspensionNotResolved
    case missingSuspendedCall(String)
    case missingPausedCall(String)
    case unsupportedContinuation(String)

    public var errorDescription: String? {
        switch self {
        case .runNotSuspended:
            return "AgentToolPlanRun must be suspended before recovery control can be applied."

        case .runNotPaused:
            return "AgentToolPlanRun must be paused before execution policy resume can be applied."

        case .suspensionAlreadyResolved:
            return "The suspended AgentToolPlan node is already resolved and is awaiting an explicit continuation decision."

        case .suspensionNotResolved:
            return "The suspended AgentToolPlan node must be retried successfully or explicitly skipped before its parent can resume."

        case .missingSuspendedCall(let callID):
            return "Suspended tool call '\(callID)' is no longer present in the immutable parent AgentToolPlan."

        case .missingPausedCall(let callID):
            return "Paused tool call '\(callID)' is no longer present at the recorded serial ToolPlan boundary."

        case .unsupportedContinuation(let path):
            return "Automatic continuation from '\(path)' is not supported because the interruption is inside batch or outcome-branch ancestry."
        }
    }
}

/// Resumable execution bookkeeping above AgentToolPlanExecutor.
///
/// The existing executor remains the authority for governed node execution,
/// execution metadata, approvals, and authored success/failure/denial branches.
/// This layer retains attempts, typed suspension reasons, explicit recovery
/// decisions, and conservative sequence-only continuation without mutating the
/// semantic AgentToolPlan.
public struct AgentToolPlanRunExecutor:
    Sendable
{
    public let invoker: ToolInvoker

    public init(
        invoker: ToolInvoker
    ) {
        self.invoker = invoker
    }

    public func start(
        _ plan: AgentToolPlan,
        runID: String = UUID().uuidString,
        relationship: AgentToolPlanRunRelationship = .root,
        context: AgentToolExecutionContext = .init(),
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> AgentToolPlanRun {
        let result = try await planExecutor.execute(
            plan,
            context: context,
            approvalHandler: approvalHandler
        )

        let attemptNumber = 1

        return AgentToolPlanRun(
            id: runID,
            plan: plan,
            relationship: relationship,
            attempts: [
                AgentToolPlanAttempt(
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
    /// The original node is executed as a small plan so its execution metadata
    /// and authored outcome branches remain intact. A successful retry resolves
    /// the interruption but does not automatically resume the parent.
    public func retry(
        _ run: AgentToolPlanRun,
        context: AgentToolExecutionContext = .init(),
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> AgentToolPlanRun {
        let suspension = try unresolvedSuspension(
            run
        )

        guard let node = run.plan.root.node(
            containingCallID: suspension.callID
        ) else {
            throw AgentToolPlanRunError.missingSuspendedCall(
                suspension.callID
            )
        }

        let attemptNumber = run.attempts.count + 1
        let retryPlan = AgentToolPlan(
            id: "\(run.plan.id).retry.\(attemptNumber)",
            root: node,
            guidelineRelations: run.plan.guidelineRelations
        )

        let rawResult = try await planExecutor.execute(
            retryPlan,
            context: context,
            approvalHandler: approvalHandler
        )
        let result = remap(
            rawResult,
            beneath: suspension.path
        )
        let revision = run.revision + 1
        let attempt = AgentToolPlanAttempt(
            number: attemptNumber,
            scope: .node(
                path: suspension.path,
                callID: suspension.callID
            ),
            result: result
        )

        var resolutions = run.resolutions
        let nextState: AgentToolPlanRunState

        if result.outcome == .succeeded {
            let resolutionKind: AgentToolPlanResolution.Kind

            if result.records.contains(
                where: { record in
                    record.path == suspension.path
                        && record.outcome == .skipped
                }
            ) {
                resolutionKind = .skipped
            } else {
                resolutionKind = .retried(
                    attemptNumber: attemptNumber
                )
            }

            let resolution = AgentToolPlanResolution(
                revision: revision,
                path: suspension.path,
                callID: suspension.callID,
                kind: resolutionKind
            )

            resolutions.append(
                resolution
            )

            nextState = resolvedState(
                plan: run.plan,
                suspension: suspension,
                resolution: resolution,
                attemptNumber: attemptNumber
            )
        } else {
            nextState = state(
                for: result,
                attemptNumber: attemptNumber
            )
        }

        return AgentToolPlanRun(
            id: run.id,
            plan: run.plan,
            relationship: run.relationship,
            attempts: run.attempts + [attempt],
            resolutions: resolutions,
            revision: revision,
            state: nextState
        )
    }

    /// Explicitly resolve the interrupted node without executing it again.
    ///
    /// This is the parent-side operation used after a manual fix or recovery
    /// child plan when the fix already performed the failed node's intended
    /// effect. Skipping still does not resume the parent automatically.
    public func skip(
        _ run: AgentToolPlanRun
    ) throws -> AgentToolPlanRun {
        let suspension = try unresolvedSuspension(
            run
        )
        let revision = run.revision + 1
        let resolution = AgentToolPlanResolution(
            revision: revision,
            path: suspension.path,
            callID: suspension.callID,
            kind: .skipped
        )

        return AgentToolPlanRun(
            id: run.id,
            plan: run.plan,
            relationship: run.relationship,
            attempts: run.attempts,
            resolutions: run.resolutions + [resolution],
            revision: revision,
            state: resolvedState(
                plan: run.plan,
                suspension: suspension,
                resolution: resolution,
                attemptNumber: suspension.attemptNumber
            )
        )
    }

    /// Resume only the untouched sequence continuation after a resolved node.
    ///
    /// The successful prefix and resolved node are never executed again.
    /// Continuation through batch or outcome-branch ancestry is deliberately
    /// rejected until those semantics are explicitly designed.
    public func resume(
        _ run: AgentToolPlanRun,
        context: AgentToolExecutionContext = .init(),
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> AgentToolPlanRun {
        guard case .suspended(let suspension) = run.state else {
            throw AgentToolPlanRunError.runNotSuspended
        }

        guard case .continuation_required = suspension.reason else {
            throw AgentToolPlanRunError.suspensionNotResolved
        }

        return try await resumeContinuation(
            run,
            afterPath: suspension.path,
            afterCallID: suspension.callID,
            context: context,
            approvalHandler: approvalHandler
        )
    }

    func resumeContinuation(
        _ run: AgentToolPlanRun,
        afterPath: String,
        afterCallID: String,
        context: AgentToolExecutionContext,
        approvalHandler: (any ToolApprovalHandler)?
    ) async throws -> AgentToolPlanRun {
        guard let continuation = run.plan.root.sequenceContinuation(
            afterCallID: afterCallID,
            path: "root"
        ) else {
            throw AgentToolPlanRunError.unsupportedContinuation(
                afterPath
            )
        }

        let revision = run.revision + 1

        guard !continuation.isEmpty else {
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

        let attemptNumber = run.attempts.count + 1
        let result = try await executeContinuation(
            continuation,
            plan: run.plan,
            attemptNumber: attemptNumber,
            context: context,
            approvalHandler: approvalHandler
        )
        let attempt = AgentToolPlanAttempt(
            number: attemptNumber,
            scope: .continuation(
                afterPath: afterPath
            ),
            result: result
        )

        return AgentToolPlanRun(
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

private extension AgentToolPlanRunExecutor {
    var planExecutor: AgentToolPlanExecutor {
        AgentToolPlanExecutor(
            invoker: invoker
        )
    }

    func unresolvedSuspension(
        _ run: AgentToolPlanRun
    ) throws -> AgentToolPlanSuspension {
        guard case .suspended(let suspension) = run.state else {
            throw AgentToolPlanRunError.runNotSuspended
        }

        switch suspension.reason {
        case .failure(_),
             .human_review:
            return suspension

        case .continuation_required:
            throw AgentToolPlanRunError.suspensionAlreadyResolved
        }
    }

    func state(
        for result: AgentToolPlanResult,
        attemptNumber: Int
    ) -> AgentToolPlanRunState {
        switch result.outcome {
        case .succeeded:
            return .completed

        case .failed:
            guard let record = result.records.last(
                where: {
                    $0.outcome == .failed
                }
            ) else {
                return .stopped(
                    .failed
                )
            }

            return .suspended(
                AgentToolPlanSuspension(
                    path: record.path,
                    callID: record.call.id,
                    attemptNumber: attemptNumber,
                    reason: .failure(
                        errorDescription: record.errorDescription
                    )
                )
            )

        case .needs_human_review:
            guard let record = result.records.last(
                where: {
                    $0.outcome == .needs_human_review
                }
            ) else {
                return .stopped(
                    .needs_human_review
                )
            }

            return .suspended(
                AgentToolPlanSuspension(
                    path: record.path,
                    callID: record.call.id,
                    attemptNumber: attemptNumber,
                    reason: .human_review
                )
            )

        case .denied,
             .skipped,
             .mixed:
            return .stopped(
                result.outcome
            )
        }
    }

    func resolvedState(
        plan: AgentToolPlan,
        suspension: AgentToolPlanSuspension,
        resolution: AgentToolPlanResolution,
        attemptNumber: Int
    ) -> AgentToolPlanRunState {
        let continuation = plan.root.sequenceContinuation(
            afterCallID: suspension.callID,
            path: "root"
        )

        if let continuation,
           continuation.isEmpty
        {
            return .completed
        }

        return .suspended(
            AgentToolPlanSuspension(
                path: suspension.path,
                callID: suspension.callID,
                attemptNumber: attemptNumber,
                reason: .continuation_required(
                    resolution
                )
            )
        )
    }

    func executeContinuation(
        _ continuation: [AgentToolPlanContinuationStep],
        plan: AgentToolPlan,
        attemptNumber: Int,
        context: AgentToolExecutionContext,
        approvalHandler: (any ToolApprovalHandler)?
    ) async throws -> AgentToolPlanResult {
        var records: [AgentToolPlanRecord] = []

        for (
            index,
            step
        ) in continuation.enumerated() {
            let continuationPlan = AgentToolPlan(
                id: "\(plan.id).resume.\(attemptNumber).\(index + 1)",
                root: step.node,
                guidelineRelations: plan.guidelineRelations
            )
            let rawResult = try await planExecutor.execute(
                continuationPlan,
                context: context,
                approvalHandler: approvalHandler
            )
            let result = remap(
                rawResult,
                beneath: step.path
            )

            records.append(
                contentsOf: result.records
            )

            guard result.outcome == .succeeded else {
                return AgentToolPlanResult(
                    planID: "\(plan.id).resume.\(attemptNumber)",
                    outcome: result.outcome,
                    records: records
                )
            }
        }

        return AgentToolPlanResult(
            planID: "\(plan.id).resume.\(attemptNumber)",
            outcome: .succeeded,
            records: records
        )
    }

    func remap(
        _ result: AgentToolPlanResult,
        beneath path: String
    ) -> AgentToolPlanResult {
        AgentToolPlanResult(
            planID: result.planID,
            outcome: result.outcome,
            records: result.records.map { record in
                AgentToolPlanRecord(
                    path: remapPath(
                        record.path,
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

    func remapPath(
        _ path: String,
        beneath originalPath: String
    ) -> String {
        guard path != "root" else {
            return originalPath
        }

        guard path.hasPrefix("root.") else {
            return path
        }

        return originalPath
            + String(
                path.dropFirst(
                    "root".count
                )
            )
    }
}

private struct AgentToolPlanContinuationStep:
    Sendable
{
    let path: String
    let node: AgentToolPlanNode
}

private extension AgentToolPlanNode {
    func node(
        containingCallID callID: String
    ) -> Self? {
        switch self {
        case .call(
            let call,
            _,
            let onSuccess,
            let onFailure,
            let onDenied
        ):
            if call.id == callID {
                return self
            }

            return (
                onSuccess
                + onFailure
                + onDenied
            ).lazy.compactMap { node in
                node.node(
                    containingCallID: callID
                )
            }.first

        case .sequence(let children),
             .batch(let children):
            return children.lazy.compactMap { node in
                node.node(
                    containingCallID: callID
                )
            }.first
        }
    }

    /// Derive untouched continuation only through ordinary sequence ancestry.
    ///
    /// Returning nil means the call exists only through ancestry whose resume
    /// semantics are intentionally not inferred yet, such as batch or an
    /// outcome branch. Returning an empty array means the call is a supported
    /// continuation point but nothing follows it.
    func sequenceContinuation(
        afterCallID callID: String,
        path: String
    ) -> [AgentToolPlanContinuationStep]? {
        switch self {
        case .call(
            let call,
            _,
            _,
            _,
            _
        ):
            return call.id == callID
                ? []
                : nil

        case .sequence(let children):
            for (
                index,
                child
            ) in children.enumerated() {
                let childPath =
                    "\(path).sequence[\(index)]"

                guard let nested = child.sequenceContinuation(
                    afterCallID: callID,
                    path: childPath
                ) else {
                    continue
                }

                let remaining = children.indices.compactMap {
                    remainingIndex -> AgentToolPlanContinuationStep? in

                    guard remainingIndex > index else {
                        return nil
                    }

                    return AgentToolPlanContinuationStep(
                        path: "\(path).sequence[\(remainingIndex)]",
                        node: children[remainingIndex]
                    )
                }

                return nested + remaining
            }

            return nil

        case .batch:
            return nil
        }
    }
}