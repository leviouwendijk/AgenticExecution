import Agentic

/// Relationship between one tool-plan run and another tool-plan run.
///
/// Keep this deliberately narrow. Session branches, delegated agent runs,
/// teams, and conversation relationships are separate concepts until their
/// shared semantics are proven.
public enum AgentToolPlanRunRelationship:
    Sendable,
    Codable,
    Hashable
{
    case root
    case recovery(
        parentRunID: String
    )
}

/// Scope represented by one execution attempt in a tool-plan run.
public enum AgentToolPlanAttemptScope:
    Sendable,
    Codable,
    Hashable
{
    case plan
    case node(
        path: String,
        callID: String
    )
}

/// One immutable execution attempt retained in run history.
public struct AgentToolPlanAttempt:
    Sendable,
    Codable,
    Hashable
{
    public let number: Int
    public let scope: AgentToolPlanAttemptScope
    public let result: AgentToolPlanResult

    public init(
        number: Int,
        scope: AgentToolPlanAttemptScope,
        result: AgentToolPlanResult
    ) {
        self.number = number
        self.scope = scope
        self.result = result
    }
}

/// Exact failure point at which a parent plan is suspended.
public struct AgentToolPlanSuspension:
    Sendable,
    Codable,
    Hashable
{
    public let path: String
    public let callID: String
    public let attemptNumber: Int
    public let errorDescription: String?

    public init(
        path: String,
        callID: String,
        attemptNumber: Int,
        errorDescription: String? = nil
    ) {
        self.path = path
        self.callID = callID
        self.attemptNumber = attemptNumber
        self.errorDescription = errorDescription
    }
}

/// A previously suspended node has executed successfully again.
///
/// This does not mean the parent automatically continued. Runtime may inspect
/// the repaired state and explicitly choose whether to resume or abort it.
public struct AgentToolPlanRecoveryPoint:
    Sendable,
    Codable,
    Hashable
{
    public let path: String
    public let callID: String
    public let resolvedAttemptNumber: Int

    public init(
        path: String,
        callID: String,
        resolvedAttemptNumber: Int
    ) {
        self.path = path
        self.callID = callID
        self.resolvedAttemptNumber = resolvedAttemptNumber
    }
}

public enum AgentToolPlanRunState:
    Sendable,
    Codable,
    Hashable
{
    case completed
    case suspended(AgentToolPlanSuspension)
    case recovered(AgentToolPlanRecoveryPoint)
    case stopped(AgentToolPlanOutcome)
}

/// Execution history for one immutable AgentToolPlan.
///
/// The semantic plan never changes. Attempts and state describe what has
/// happened to that plan and where execution may later continue.
public struct AgentToolPlanRun:
    Sendable,
    Codable,
    Hashable,
    Identifiable
{
    public let id: String
    public let plan: AgentToolPlan
    public let relationship: AgentToolPlanRunRelationship
    public let attempts: [AgentToolPlanAttempt]
    public let state: AgentToolPlanRunState

    public var latestAttempt: AgentToolPlanAttempt? {
        attempts.last
    }

    public var latestResult: AgentToolPlanResult? {
        latestAttempt?.result
    }

    /// Monotonic execution revision suitable for later persisted optimistic
    /// concurrency checks.
    public var revision: Int {
        attempts.count
    }
}
