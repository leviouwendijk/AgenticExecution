public struct AgentToolRegistration: Sendable {
    private let applyHandler: @Sendable (
        inout ToolRegistry
    ) throws -> Void

    public init(
        apply: @escaping @Sendable (
            inout ToolRegistry
        ) throws -> Void
    ) {
        self.applyHandler = apply
    }

    public func apply(
        into registry: inout ToolRegistry
    ) throws {
        try applyHandler(
            &registry
        )
    }
}

public extension AgentToolRegistration {
    static func tool(
        _ tool: any AgentTool
    ) -> Self {
        .init { registry in
            try registry.register(
                tool
            )
        }
    }

    static func declaration(
        _ declaration: AgentToolDeclaration
    ) -> Self {
        .init { registry in
            try registry.register(
                declaration.makeTool()
            )
        }
    }

    static func toolSet(
        _ toolSet: any AgentToolSet
    ) -> Self {
        .init { registry in
            try registry.register(
                toolSet
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
    ) -> [AgentToolRegistration] where T: AgentTool {
        [
            .tool(expression)
        ]
    }

    public static func buildExpression(
        _ expression: any AgentTool
    ) -> [AgentToolRegistration] {
        [
            .tool(expression)
        ]
    }

    public static func buildExpression(
        _ expression: AgentToolDeclaration
    ) -> [AgentToolRegistration] {
        [
            .declaration(expression)
        ]
    }

    public static func buildExpression(
        _ expression: [AgentToolDeclaration]
    ) -> [AgentToolRegistration] {
        expression.map {
            .declaration($0)
        }
    }

    public static func buildExpression(
        _ expression: any AgentToolSet
    ) -> [AgentToolRegistration] {
        [
            .toolSet(expression)
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
