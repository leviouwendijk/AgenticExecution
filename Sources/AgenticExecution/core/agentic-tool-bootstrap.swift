import Agentic

extension Agentic {
    public struct ToolBootstrapAPI: Sendable {
        public init() {}

        public func registry(
            toolProviders: [any AgentToolProvider] = [],
            configuration: ToolRegistryConfiguration = .default
        ) throws -> ToolRegistry {
            var registry = ToolRegistry()

            for provider in toolProviders {
                try registry.register(
                    from: provider
                )
            }

            return try complete(
                registry,
                configuration: configuration
            )
        }

        public func registry(
            configuration: ToolRegistryConfiguration = .default,
            @AgentToolBuilder _ content: () throws -> [AgentToolRegistration]
        ) throws -> ToolRegistry {
            var registry = ToolRegistry()

            try registry.register(
                content
            )

            return try complete(
                registry,
                configuration: configuration
            )
        }

        public static func registry(
            toolProviders: [any AgentToolProvider] = [],
            configuration: ToolRegistryConfiguration = .default
        ) throws -> ToolRegistry {
            try Self().registry(
                toolProviders: toolProviders,
                configuration: configuration
            )
        }

        public static func registry(
            configuration: ToolRegistryConfiguration = .default,
            @AgentToolBuilder _ content: () throws -> [AgentToolRegistration]
        ) throws -> ToolRegistry {
            try Self().registry(
                configuration: configuration,
                content
            )
        }

        private func complete(
            _ registry: ToolRegistry,
            configuration: ToolRegistryConfiguration
        ) throws -> ToolRegistry {
            var registry = registry

            if configuration.includeIntrinsicTools {
                try registry.installIntrinsicTools()
            }

            return registry
        }
    }
}

extension Agentic {
    public static let tool: ToolBootstrapAPI = .init()
}
