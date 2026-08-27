public protocol AgentToolProvider: Sendable {
    func registerTools(
        into registry: inout ToolRegistry
    ) throws
}
