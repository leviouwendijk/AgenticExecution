import Agentic
import Macros
import Schema

public struct WorkspaceTarget:
    Sendable,
    Codable,
    Hashable
{
    public let subpath: String

    public init(
        subpath: String
    ) {
        self.subpath = subpath
    }
}

public enum ToolInvocation {}

public extension ToolInvocation {
    struct Execution:
        Sendable,
        Codable,
        Hashable
    {
        public let workspace: WorkspaceTarget?

        public init(
            workspace: WorkspaceTarget? = nil
        ) {
            self.workspace = workspace
        }
    }
}

public extension ToolInvocation {
    @JSONSchema
    struct Review:
        Sendable,
        Codable,
        Hashable
    {
        public let call: ToolCall
        public let preflight: ToolPreflight
        public let requirement: ApprovalRequirement
        public let references: [Reference]

        public init(
            call: ToolCall,
            preflight: ToolPreflight,
            requirement: ApprovalRequirement,
            references: [Reference] = []
        ) {
            self.call = call
            self.preflight = preflight
            self.requirement = requirement
            self.references = references
        }
    }

    @JSONSchema
    struct Prepared:
        Sendable,
        Codable,
        Hashable
    {
        public let review: Review
        public let operation: PreparedOperation.Envelope

        public init(
            review: Review,
            operation: PreparedOperation.Envelope
        ) {
            self.review = review
            self.operation = operation
        }
    }

    enum Interruption:
        String,
        Sendable,
        Codable,
        Hashable,
        CaseIterable
    {
        case human_review
    }

    enum Outcome:
        Sendable,
        Codable,
        Hashable
    {
        case executed(ToolExecutionResult)
        case denied
        case skipped
        case interrupted(Interruption)
    }

    struct Result:
        Sendable,
        Codable,
        Hashable
    {
        public let review: Review
        public let outcome: Outcome

        public init(
            review: Review,
            outcome: Outcome
        ) {
            self.review = review
            self.outcome = outcome
        }

        public var execution: ToolExecutionResult? {
            guard case .executed(let execution) = outcome else {
                return nil
            }

            return execution
        }

        public var decision: ApprovalDecision {
            switch outcome {
            case .executed:
                return .approved

            case .denied:
                return .denied

            case .skipped:
                return .skipped

            case .interrupted(.human_review):
                return .needshuman
            }
        }

        public var executed: Bool {
            execution != nil
        }
    }
}
