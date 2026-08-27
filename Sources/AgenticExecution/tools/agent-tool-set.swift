public protocol AgentToolSet: Sendable {
    func register(
        into registry: inout ToolRegistry
    ) throws
}
