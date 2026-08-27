public extension ToolRegistry {
    init(
        @AgentToolBuilder _ content: () throws -> [AgentToolRegistration]
    ) throws {
        self.init()

        try register(
            content
        )
    }

    mutating func register(
        @AgentToolBuilder _ content: () throws -> [AgentToolRegistration]
    ) throws {
        let registrations = try content()

        for registration in registrations {
            try registration.apply(
                into: &self
            )
        }
    }
}

public func tools(
    @AgentToolBuilder _ content: () throws -> [AgentToolRegistration]
) rethrows -> [AgentToolRegistration] {
    try content()
}
