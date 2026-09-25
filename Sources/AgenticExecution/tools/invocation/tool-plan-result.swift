import Agentic

public extension ToolPlan {
    enum Outcome:
        String,
        Sendable,
        Codable,
        Hashable,
        CaseIterable
    {
        case succeeded
        case failed
        case denied
        case needs_human_review
        case skipped
        case mixed
    }

    struct Record:
        Sendable,
        Codable,
        Hashable,
        Identifiable
    {
        public let path: String
        public let call: ToolCall
        public let outcome: Outcome
        public let invocation: ToolInvocation.Result?
        public let toolFailure: ToolCall.Failure?
        public let errorDescription: String?
        public let skipReason: String?

        public init(
            path: String,
            call: ToolCall,
            outcome: Outcome,
            invocation: ToolInvocation.Result? = nil,
            toolFailure: ToolCall.Failure? = nil,
            errorDescription: String? = nil,
            skipReason: String? = nil
        ) {
            self.path = path
            self.call = call
            self.outcome = outcome
            self.invocation = invocation
            self.toolFailure = toolFailure
            self.errorDescription = errorDescription
            self.skipReason = skipReason
        }

        public var id: String {
            call.id
        }
    }

    struct Result:
        Sendable,
        Codable,
        Hashable
    {
        public let planID: String
        public let outcome: Outcome
        public let records: [Record]

        public init(
            planID: String,
            outcome: Outcome,
            records: [Record]
        ) {
            self.planID = planID
            self.outcome = outcome
            self.records = records
        }

        public var executedCount: Int {
            records.filter {
                $0.invocation?.executed == true
            }.count
        }

        public var skippedCount: Int {
            records.filter {
                $0.outcome == .skipped
            }.count
        }
    }
}
