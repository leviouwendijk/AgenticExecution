import Agentic

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
    struct Review: Sendable, Codable, Hashable {
        public let call: ToolCall
        public let preflight: ToolPreflight
        public let requirement: ApprovalRequirement
        public let guidelineRelations: [AgentGuidelineRelation]

        public init(
            call: ToolCall,
            preflight: ToolPreflight,
            requirement: ApprovalRequirement,
            guidelineRelations: [AgentGuidelineRelation] = []
        ) {
            self.call = call
            self.preflight = preflight
            self.requirement = requirement
            self.guidelineRelations = guidelineRelations
        }

        private enum CodingKeys:
            String,
            CodingKey
        {
            case call
            case preflight
            case requirement
            case guidelineRelations
        }

        public init(
            from decoder: any Decoder
        ) throws {
            let container = try decoder.container(
                keyedBy: CodingKeys.self
            )

            self.call = try container.decode(
                ToolCall.self,
                forKey: .call
            )

            self.preflight = try container.decode(
                ToolPreflight.self,
                forKey: .preflight
            )

            self.requirement = try container.decode(
                ApprovalRequirement.self,
                forKey: .requirement
            )

            self.guidelineRelations =
                try container.decodeIfPresent(
                    [AgentGuidelineRelation].self,
                    forKey: .guidelineRelations
                )
                ?? []
        }

        public func encode(
            to encoder: any Encoder
        ) throws {
            var container = encoder.container(
                keyedBy: CodingKeys.self
            )

            try container.encode(
                call,
                forKey: .call
            )

            try container.encode(
                preflight,
                forKey: .preflight
            )

            try container.encode(
                requirement,
                forKey: .requirement
            )

            try container.encode(
                guidelineRelations,
                forKey: .guidelineRelations
            )
        }
    }

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
