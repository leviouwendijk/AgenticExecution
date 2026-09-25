import Agentic
import Foundation

public extension ToolPlan {
    /// Durable execution history for one immutable ToolPlan.
    ///
    /// Attempts record actual execution, resolutions record explicit workflow
    /// decisions, and state records either a terminal plan outcome or one exact
    /// typed interruption point.
    struct Run:
        Sendable,
        Codable,
        Hashable,
        Identifiable
    {
        public let id: String
        public let plan: ToolPlan
        public let relationship: Relationship
        public let attempts: [Attempt]
        public let resolutions: [Resolution]
        public let revision: Int
        public let state: State

        public init(
            id: String,
            plan: ToolPlan,
            relationship: Relationship,
            attempts: [Attempt],
            resolutions: [Resolution] = [],
            revision: Int,
            state: State
        ) {
            self.id = id
            self.plan = plan
            self.relationship = relationship
            self.attempts = attempts
            self.resolutions = resolutions
            self.revision = revision
            self.state = state
        }

        public var latestAttempt: Attempt? {
            attempts.last
        }

        public var latestResult: ToolPlan.Result? {
            latestAttempt?.result
        }

        public var latestResolution: Resolution? {
            resolutions.last
        }
    }
}

public extension ToolPlan.Run {
    enum Relationship:
        Sendable,
        Codable,
        Hashable
    {
        case root
        case recovery(
            parentRunID: String
        )
    }

    struct Attempt:
        Sendable,
        Codable,
        Hashable
    {
        public enum Scope:
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

        public let number: Int
        public let scope: Scope
        public let result: ToolPlan.Result

        public init(
            number: Int,
            scope: Scope,
            result: ToolPlan.Result
        ) {
            self.number = number
            self.scope = scope
            self.result = result
        }
    }

    struct Resolution:
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

    struct Point:
        Sendable,
        Codable,
        Hashable
    {
        public let path: String
        public let callID: String
        public let attemptNumber: Int

        public init(
            path: String,
            callID: String,
            attemptNumber: Int
        ) {
            self.path = path
            self.callID = callID
            self.attemptNumber = attemptNumber
        }
    }

    struct Failure:
        Sendable,
        Codable,
        Hashable
    {
        public let toolFailure: ToolCall.Failure?
        public let recovery: Recovery.Record?
        public let errorDescription: String?

        public init(
            toolFailure: ToolCall.Failure? = nil,
            recovery: Recovery.Record? = nil,
            errorDescription: String? = nil
        ) {
            self.toolFailure = toolFailure
            self.recovery = recovery
            self.errorDescription = errorDescription
        }
    }

    struct Interruption:
        Sendable,
        Codable,
        Hashable
    {
        public enum Policy:
            String,
            Sendable,
            Codable,
            Hashable
        {
            case single_step
            case requested
        }

        public enum Reason:
            Sendable,
            Codable,
            Hashable
        {
            case policy(Policy)
            case failure(Failure)
            case human_review
            case continuation_required(
                Resolution
            )
        }

        public let point: Point
        public let reason: Reason

        public init(
            point: Point,
            reason: Reason
        ) {
            self.point = point
            self.reason = reason
        }
    }

    enum Error:
        Swift.Error,
        Sendable,
        LocalizedError,
        Equatable
    {
        case runNotInterrupted
        case interruptionAlreadyResolved
        case interruptionNotResolved
        case runNotPolicyInterrupted
        case missingInterruptedCall(String)
        case missingPolicyBoundary(String)
        case retryNotSafe(Recovery.RetrySafety)
        case unsupportedContinuation(String)

        public var errorDescription: String? {
            switch self {
            case .runNotInterrupted:
                return "ToolPlan.Run must be interrupted before recovery control can be applied."

            case .interruptionAlreadyResolved:
                return "The interrupted ToolPlan node is already resolved and is awaiting an explicit continuation decision."

            case .interruptionNotResolved:
                return "The interrupted ToolPlan node must be retried successfully or explicitly skipped before its parent can resume."

            case .runNotPolicyInterrupted:
                return "ToolPlan.Run must be interrupted by execution policy before policy resume can be applied."

            case .missingInterruptedCall(let callID):
                return "Interrupted tool call '\(callID)' is no longer present in the immutable parent ToolPlan."

            case .missingPolicyBoundary(let callID):
                return "Policy-interrupted tool call '\(callID)' is no longer present at the recorded ToolPlan boundary."

            case .retryNotSafe(let retry):
                return "Interrupted ToolPlan node cannot be retried because Recovery marks retry safety as '\(retry.rawValue)'."

            case .unsupportedContinuation(let path):
                return "Automatic continuation from '\(path)' is not supported because the interruption is inside batch or outcome-branch ancestry."
            }
        }
    }

    enum State:
        Sendable,
        Codable,
        Hashable
    {
        case terminal(ToolPlan.Outcome)
        case interrupted(Interruption)
    }
}
