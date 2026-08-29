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

/// Scope represented by one actual execution attempt in a tool-plan run.
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
    case continuation(
        afterPath: String
    )
}

/// One actual execution attempt retained in run history.
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

/// Explicit resolution applied to an interrupted tool-plan node.
///
/// A retry is recorded only after that retry succeeds. A skip means the
/// interrupted node was deliberately treated as externally resolved or
/// waived without executing it again. This supports manual fixes and nested
/// recovery runs without pretending the parent performed the repair itself.
public struct AgentToolPlanResolution:
    Sendable,
    Codable,
    Hashable
{
    public enum Kind:
        Sendable,
        Codable,
        Hashable
    {
        case retried(
            attemptNumber: Int
        )
        case skipped
    }

    public let revision: Int
    public let path: String
    public let callID: String
    public let kind: Kind

    public init(
        revision: Int,
        path: String,
        callID: String,
        kind: Kind
    ) {
        self.revision = revision
        self.path = path
        self.callID = callID
        self.kind = kind
    }
}

/// Why execution is intentionally suspended at one tool-plan node.
public enum AgentToolPlanSuspensionReason:
    Sendable,
    Codable,
    Hashable
{
    case failure(
        errorDescription: String?
    )
    case human_review
    case continuation_required(
        AgentToolPlanResolution
    )
}

/// Exact point at which one immutable parent plan is suspended.
public struct AgentToolPlanSuspension:
    Sendable,
    Codable,
    Hashable
{
    public let path: String
    public let callID: String
    public let attemptNumber: Int
    public let reason: AgentToolPlanSuspensionReason

    public init(
        path: String,
        callID: String,
        attemptNumber: Int,
        reason: AgentToolPlanSuspensionReason
    ) {
        self.path = path
        self.callID = callID
        self.attemptNumber = attemptNumber
        self.reason = reason
    }
}

public enum AgentToolPlanRunState:
    Sendable,
    Codable,
    Hashable
{
    case completed
    case suspended(AgentToolPlanSuspension)
    case stopped(AgentToolPlanOutcome)
}

/// Execution history for one immutable AgentToolPlan.
///
/// The semantic plan never changes. Attempts record actual execution;
/// resolutions record explicit recovery decisions such as successful retry or
/// skip; revision advances for every run-state transition so later durable
/// storage can perform optimistic concurrency checks even when no tool was
/// executed by that transition.
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
    public let resolutions: [AgentToolPlanResolution]
    public let revision: Int
    public let state: AgentToolPlanRunState

    public init(
        id: String,
        plan: AgentToolPlan,
        relationship: AgentToolPlanRunRelationship,
        attempts: [AgentToolPlanAttempt],
        resolutions: [AgentToolPlanResolution] = [],
        revision: Int,
        state: AgentToolPlanRunState
    ) {
        self.id = id
        self.plan = plan
        self.relationship = relationship
        self.attempts = attempts
        self.resolutions = resolutions
        self.revision = revision
        self.state = state
    }

    public var latestAttempt: AgentToolPlanAttempt? {
        attempts.last
    }

    public var latestResult: AgentToolPlanResult? {
        latestAttempt?.result
    }

    public var latestResolution: AgentToolPlanResolution? {
        resolutions.last
    }
}
