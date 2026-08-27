import Agentic

public enum ToolInvocation {}

public extension ToolInvocation {
    struct Review: Sendable, Codable, Hashable {
        public let call: AgentToolCall
        public let preflight: ToolPreflight
        public let requirement: ApprovalRequirement
        public let guidelineRelations: [AgentGuidelineRelation]

        public init(
            call: AgentToolCall,
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
                AgentToolCall.self,
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

    struct Result: Sendable, Codable, Hashable {
        public let review: Review
        public let decision: ApprovalDecision
        public let toolResult: AgentToolResult?

        public init(
            review: Review,
            decision: ApprovalDecision,
            toolResult: AgentToolResult?
        ) {
            self.review = review
            self.decision = decision
            self.toolResult = toolResult
        }

        public var executed: Bool {
            toolResult != nil
        }
    }
}
