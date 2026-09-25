import Agentic

public extension ToolPlan {
    enum ExecutionPolicy:
        String,
        Sendable,
        Codable,
        Hashable,
        CaseIterable
    {
        case continuous
        case single_step
    }
}
