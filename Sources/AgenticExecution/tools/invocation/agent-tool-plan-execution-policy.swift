public enum AgentToolPlanExecutionPolicy:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case continuous
    case single_step
}

public enum AgentToolPlanPauseReason:
    String,
    Sendable,
    Codable,
    Hashable
{
    case single_step
    case requested
}

public struct AgentToolPlanPause:
    Sendable,
    Codable,
    Hashable
{
    public let afterPath: String
    public let afterCallID: String
    public let attemptNumber: Int
    public let reason: AgentToolPlanPauseReason

    public init(
        afterPath: String,
        afterCallID: String,
        attemptNumber: Int,
        reason: AgentToolPlanPauseReason
    ) {
        self.afterPath = afterPath
        self.afterCallID = afterCallID
        self.attemptNumber = attemptNumber
        self.reason = reason
    }
}
