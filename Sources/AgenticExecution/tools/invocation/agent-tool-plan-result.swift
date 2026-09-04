import Agentic

public enum AgentToolPlanOutcome:
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

public struct AgentToolPlanRecord:
    Sendable,
    Codable,
    Hashable,
    Identifiable
{
    public let path: String
    public let call: AgentToolCall
    public let outcome: AgentToolPlanOutcome
    public let invocation: ToolInvocation.Result?
    public let toolFailure: AgentToolCallFailure?
    public let errorDescription: String?
    public let skipReason: String?

    public init(
        path: String,
        call: AgentToolCall,
        outcome: AgentToolPlanOutcome,
        invocation: ToolInvocation.Result? = nil,
        toolFailure: AgentToolCallFailure? = nil,
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

public struct AgentToolPlanResult:
    Sendable,
    Codable,
    Hashable
{
    public let planID: String
    public let outcome: AgentToolPlanOutcome
    public let records: [AgentToolPlanRecord]

    public init(
        planID: String,
        outcome: AgentToolPlanOutcome,
        records: [AgentToolPlanRecord]
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