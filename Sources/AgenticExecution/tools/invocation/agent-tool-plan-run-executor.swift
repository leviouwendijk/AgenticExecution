import Agentic
import Foundation

public enum AgentToolPlanRunError:
    Error,
    Sendable,
    LocalizedError,
    Equatable
{
    case runNotSuspended
    case missingSuspendedCall(String)

    public var errorDescription: String? {
        switch self {
        case .runNotSuspended:
            return "AgentToolPlanRun must be suspended before its failed node can be retried."

        case .missingSuspendedCall(let callID):
            return "Suspended tool call '\(callID)' is no longer present in the immutable parent AgentToolPlan."
        }
    }
}

/// Resumable execution bookkeeping above AgentToolPlanExecutor.
///
/// The existing executor remains the authority for governed node execution,
/// execution metadata, approvals, and authored success/failure/denial branches.
/// This layer retains attempts and identifies recovery points without mutating
/// the semantic AgentToolPlan.
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
            state: initialState(
                for: result,
                attemptNumber: attemptNumber
            )
        )
    }

    /// Retry exactly the node recorded by the current suspension.
    ///
    /// The retry executes the original node as a small plan, preserving its
    /// execution metadata and authored outcome branches. A successful retry
    /// records recovery but deliberately does not resume the parent plan.
    public func retry(
        _ run: AgentToolPlanRun,
        context: AgentToolExecutionContext = .init(),
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> AgentToolPlanRun {
        guard case .suspended(let suspension) = run.state else {
            throw AgentToolPlanRunError.runNotSuspended
        }

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

        let result = try await planExecutor.execute(
            retryPlan,
            context: context,
            approvalHandler: approvalHandler
        )

        let attempt = AgentToolPlanAttempt(
            number: attemptNumber,
            scope: .node(
                path: suspension.path,
                callID: suspension.callID
            ),
            result: result
        )

        return AgentToolPlanRun(
            id: run.id,
            plan: run.plan,
            relationship: run.relationship,
            attempts: run.attempts + [attempt],
            state: retryState(
                for: result,
                suspension: suspension,
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

    func initialState(
        for result: AgentToolPlanResult,
        attemptNumber: Int
    ) -> AgentToolPlanRunState {
        if result.outcome == .succeeded {
            return .completed
        }

        if result.outcome == .failed,
           let record = result.records.last(
                where: {
                    $0.outcome == .failed
                }
           )
        {
            return .suspended(
                AgentToolPlanSuspension(
                    path: record.path,
                    callID: record.call.id,
                    attemptNumber: attemptNumber,
                    errorDescription: record.errorDescription
                )
            )
        }

        return .stopped(
            result.outcome
        )
    }

    func retryState(
        for result: AgentToolPlanResult,
        suspension: AgentToolPlanSuspension,
        attemptNumber: Int
    ) -> AgentToolPlanRunState {
        if result.outcome == .succeeded {
            return .recovered(
                AgentToolPlanRecoveryPoint(
                    path: suspension.path,
                    callID: suspension.callID,
                    resolvedAttemptNumber: attemptNumber
                )
            )
        }

        if result.outcome == .failed,
           let record = result.records.last(
                where: {
                    $0.outcome == .failed
                }
           )
        {
            return .suspended(
                AgentToolPlanSuspension(
                    path: remapRetryPath(
                        record.path,
                        beneath: suspension.path
                    ),
                    callID: record.call.id,
                    attemptNumber: attemptNumber,
                    errorDescription: record.errorDescription
                )
            )
        }

        return .stopped(
            result.outcome
        )
    }

    func remapRetryPath(
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
}
