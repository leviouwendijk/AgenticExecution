import Agentic

extension Agentic {
    public struct ToolBootstrapAPI: Sendable {
        public init() {}

        public func registry(
            toolSets: [any AgentToolSet] = [],
            toolProviders: [any AgentToolProvider] = []
        ) throws -> ToolRegistry {
            var registry = ToolRegistry()

            for toolSet in toolSets {
                try registry.register(
                    toolSet
                )
            }

            for provider in toolProviders {
                try registry.register(
                    from: provider
                )
            }

            return registry
        }

        public func registry(
            @AgentToolBuilder _ content: () throws -> [AgentToolRegistration]
        ) throws -> ToolRegistry {
            var registry = ToolRegistry()

            try registry.register(
                content
            )

            return registry
        }

        public static func registry(
            toolSets: [any AgentToolSet] = [],
            toolProviders: [any AgentToolProvider] = []
        ) throws -> ToolRegistry {
            try Self().registry(
                toolSets: toolSets,
                toolProviders: toolProviders
            )
        }

        public static func registry(
            @AgentToolBuilder _ content: () throws -> [AgentToolRegistration]
        ) throws -> ToolRegistry {
            try Self().registry(
                content
            )
        }
    }
}

extension Agentic {
    public static let tool: ToolBootstrapAPI = .init()
}
