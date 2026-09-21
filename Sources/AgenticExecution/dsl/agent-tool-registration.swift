import Agentic

public struct AgentToolRegistration: Sendable {
    public let collection: AgentToolCollectionMetadata?

    private let applyHandler: @Sendable (
        inout ToolRegistry
    ) throws -> Void

    public init(
        collection: AgentToolCollectionMetadata? = nil,
        apply: @escaping @Sendable (
            inout ToolRegistry
        ) throws -> Void
    ) {
        self.collection = collection
        self.applyHandler = apply
    }

    public func apply(
        into registry: inout ToolRegistry
    ) throws {
        try applyHandler(
            &registry
        )
    }

    public func assigning(
        collection: AgentToolCollectionMetadata
    ) -> Self {
        .init(
            collection: collection,
            apply: applyHandler
        )
    }
}

public extension AgentToolRegistration {
    static func tool<T>(
        _ tool: T,
        modelContract: AgentToolModelContract? = nil,
        execution: AgentToolExecutionContract = .fixed
    ) -> Self where T: Tool {
        .init { registry in
            try registry.register(
                tool,
                modelContract: modelContract,
                execution: execution
            )
        }
    }

    static func provider(
        _ provider: any AgentToolProvider
    ) -> Self {
        .init { registry in
            try registry.register(
                from: provider
            )
        }
    }
}

@resultBuilder
public enum AgentToolBuilder {
    public static func buildBlock(
        _ components: [AgentToolRegistration]...
    ) -> [AgentToolRegistration] {
        components.flatMap {
            $0
        }
    }

    public static func buildExpression<T>(
        _ expression: T
    ) -> [AgentToolRegistration] where T: Tool {
        [
            .tool(expression)
        ]
    }

    public static func buildExpression(
        _ expression: any AgentToolProvider
    ) -> [AgentToolRegistration] {
        [
            .provider(expression)
        ]
    }

    public static func buildExpression(
        _ expression: AgentToolRegistration
    ) -> [AgentToolRegistration] {
        [
            expression
        ]
    }

    public static func buildExpression(
        _ expression: [AgentToolRegistration]
    ) -> [AgentToolRegistration] {
        expression
    }

    public static func buildOptional(
        _ component: [AgentToolRegistration]?
    ) -> [AgentToolRegistration] {
        component ?? []
    }

    public static func buildEither(
        first component: [AgentToolRegistration]
    ) -> [AgentToolRegistration] {
        component
    }

    public static func buildEither(
        second component: [AgentToolRegistration]
    ) -> [AgentToolRegistration] {
        component
    }

    public static func buildArray(
        _ components: [[AgentToolRegistration]]
    ) -> [AgentToolRegistration] {
        components.flatMap {
            $0
        }
    }

    public static func buildLimitedAvailability(
        _ component: [AgentToolRegistration]
    ) -> [AgentToolRegistration] {
        component
    }
}
