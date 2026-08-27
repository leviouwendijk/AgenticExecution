import Agentic
import Primitives

public struct AgentToolEmptyInput: Sendable, Codable, Hashable {
    public init() {}
}

public struct AgentToolEmptyOutput: Sendable, Codable, Hashable {
    public init() {}
}

public enum AgentToolDeclarationComponent: Sendable {
    case description(String)
    case schema(JSONValue?)
    case risk(ActionRisk)
    case preflight(AgentToolPreflightHandler)
    case call(AgentToolCallHandler)
}

public struct AgentToolDeclaration: Sendable {
    public var identifier: AgentToolIdentifier
    public var components: [AgentToolDeclarationComponent]

    public init(
        identifier: AgentToolIdentifier,
        components: [AgentToolDeclarationComponent] = []
    ) {
        self.identifier = identifier
        self.components = components
    }

    public func makeTool() throws -> ClosureAgentTool {
        var description = ""
        var inputSchema: JSONValue?
        var risk: ActionRisk = .observe
        var preflightHandler: AgentToolPreflightHandler?
        var callHandler: AgentToolCallHandler?

        for component in components {
            switch component {
            case .description(let value):
                description = value

            case .schema(let value):
                inputSchema = value

            case .risk(let value):
                risk = value

            case .preflight(let value):
                preflightHandler = value

            case .call(let value):
                callHandler = value
            }
        }

        guard let callHandler else {
            throw AgentToolDeclarationError.missingCall(
                identifier.rawValue
            )
        }

        return ClosureAgentTool(
            identifier: identifier,
            description: description,
            inputSchema: inputSchema,
            risk: risk,
            preflight: preflightHandler,
            call: callHandler
        )
    }
}

public extension AgentToolDeclaration {
    func description(
        _ description: String
    ) -> Self {
        appending(
            .description(description)
        )
    }

    func describe(
        _ description: String
    ) -> Self {
        self.description(
            description
        )
    }

    func schema(
        _ inputSchema: JSONValue?
    ) -> Self {
        appending(
            .schema(inputSchema)
        )
    }

    func risk(
        _ risk: ActionRisk
    ) -> Self {
        appending(
            .risk(risk)
        )
    }

    func preflight(
        _ preflight: @escaping AgentToolPreflightHandler
    ) -> Self {
        appending(
            .preflight(preflight)
        )
    }

    func raw(
        _ call: @escaping AgentToolCallHandler
    ) -> Self {
        appending(
            .call(call)
        )
    }

    private func appending(
        _ component: AgentToolDeclarationComponent
    ) -> Self {
        var copy = self
        copy.components.append(
            component
        )
        return copy
    }
}

public extension AgentToolDeclarationComponent {
    static func raw(
        _ call: @escaping AgentToolCallHandler
    ) -> Self {
        .call(
            call
        )
    }

    static func call<Input, Output>(
        input _: Input.Type,
        output _: Output.Type = Output.self,
        _ call: @escaping @Sendable (
            Input,
            AgentToolContext
        ) async throws -> Output
    ) -> Self where Input: Decodable & Sendable, Output: Encodable & Sendable {
        .call { value, context in
            let decoded = try JSONToolBridge.decode(
                Input.self,
                from: value
            )

            let output = try await call(
                decoded,
                context
            )

            return try JSONToolBridge.encode(
                output
            )
        }
    }

    static func call<Input, Output>(
        input _: Input.Type,
        output _: Output.Type = Output.self,
        _ call: @escaping @Sendable (
            Input
        ) async throws -> Output
    ) -> Self where Input: Decodable & Sendable, Output: Encodable & Sendable {
        .call { value, _ in
            let decoded = try JSONToolBridge.decode(
                Input.self,
                from: value
            )

            let output = try await call(
                decoded
            )

            return try JSONToolBridge.encode(
                output
            )
        }
    }

    static func call<Output>(
        output _: Output.Type = Output.self,
        _ call: @escaping @Sendable (
            AgentToolContext
        ) async throws -> Output
    ) -> Self where Output: Encodable & Sendable {
        .call { _, context in
            let output = try await call(
                context
            )

            return try JSONToolBridge.encode(
                output
            )
        }
    }

    static func call<Output>(
        output _: Output.Type = Output.self,
        _ call: @escaping @Sendable () async throws -> Output
    ) -> Self where Output: Encodable & Sendable {
        .call { _, _ in
            let output = try await call()

            return try JSONToolBridge.encode(
                output
            )
        }
    }

    static func effect<Input>(
        input _: Input.Type,
        _ call: @escaping @Sendable (
            Input,
            AgentToolContext
        ) async throws -> Void
    ) -> Self where Input: Decodable & Sendable {
        .call { value, context in
            let decoded = try JSONToolBridge.decode(
                Input.self,
                from: value
            )

            try await call(
                decoded,
                context
            )

            return try JSONToolBridge.encode(
                AgentToolEmptyOutput()
            )
        }
    }

    static func effect<Input>(
        input _: Input.Type,
        _ call: @escaping @Sendable (
            Input
        ) async throws -> Void
    ) -> Self where Input: Decodable & Sendable {
        .call { value, _ in
            let decoded = try JSONToolBridge.decode(
                Input.self,
                from: value
            )

            try await call(
                decoded
            )

            return try JSONToolBridge.encode(
                AgentToolEmptyOutput()
            )
        }
    }

    static func effect(
        _ call: @escaping @Sendable (
            AgentToolContext
        ) async throws -> Void
    ) -> Self {
        .call { _, context in
            try await call(
                context
            )

            return try JSONToolBridge.encode(
                AgentToolEmptyOutput()
            )
        }
    }

    static func effect(
        _ call: @escaping @Sendable () async throws -> Void
    ) -> Self {
        .call { _, _ in
            try await call()

            return try JSONToolBridge.encode(
                AgentToolEmptyOutput()
            )
        }
    }
}

@resultBuilder
public enum AgentToolDeclarationBuilder {
    public static func buildBlock(
        _ components: [AgentToolDeclarationComponent]...
    ) -> [AgentToolDeclarationComponent] {
        components.flatMap {
            $0
        }
    }

    public static func buildExpression(
        _ expression: AgentToolDeclarationComponent
    ) -> [AgentToolDeclarationComponent] {
        [
            expression
        ]
    }

    public static func buildExpression(
        _ expression: [AgentToolDeclarationComponent]
    ) -> [AgentToolDeclarationComponent] {
        expression
    }

    public static func buildOptional(
        _ component: [AgentToolDeclarationComponent]?
    ) -> [AgentToolDeclarationComponent] {
        component ?? []
    }

    public static func buildEither(
        first component: [AgentToolDeclarationComponent]
    ) -> [AgentToolDeclarationComponent] {
        component
    }

    public static func buildEither(
        second component: [AgentToolDeclarationComponent]
    ) -> [AgentToolDeclarationComponent] {
        component
    }

    public static func buildArray(
        _ components: [[AgentToolDeclarationComponent]]
    ) -> [AgentToolDeclarationComponent] {
        components.flatMap {
            $0
        }
    }

    public static func buildLimitedAvailability(
        _ component: [AgentToolDeclarationComponent]
    ) -> [AgentToolDeclarationComponent] {
        component
    }
}

public func tool(
    _ identifier: AgentToolIdentifier,
    @AgentToolDeclarationBuilder _ content: () throws -> [AgentToolDeclarationComponent]
) rethrows -> AgentToolDeclaration {
    AgentToolDeclaration(
        identifier: identifier,
        components: try content()
    )
}

public func description(
    _ description: String
) -> AgentToolDeclarationComponent {
    .description(
        description
    )
}

public func toolDescription(
    _ description: String
) -> AgentToolDeclarationComponent {
    .description(
        description
    )
}

public func schema(
    _ inputSchema: JSONValue?
) -> AgentToolDeclarationComponent {
    .schema(
        inputSchema
    )
}

public func toolSchema(
    _ inputSchema: JSONValue?
) -> AgentToolDeclarationComponent {
    .schema(
        inputSchema
    )
}

public func risk(
    _ risk: ActionRisk
) -> AgentToolDeclarationComponent {
    .risk(
        risk
    )
}

public func toolRisk(
    _ risk: ActionRisk
) -> AgentToolDeclarationComponent {
    .risk(
        risk
    )
}

public func preflight(
    _ preflight: @escaping AgentToolPreflightHandler
) -> AgentToolDeclarationComponent {
    .preflight(
        preflight
    )
}

public func toolPreflight(
    _ preflight: @escaping AgentToolPreflightHandler
) -> AgentToolDeclarationComponent {
    .preflight(
        preflight
    )
}

public func raw(
    _ call: @escaping AgentToolCallHandler
) -> AgentToolDeclarationComponent {
    .call(
        call
    )
}

public func rawToolCall(
    _ call: @escaping AgentToolCallHandler
) -> AgentToolDeclarationComponent {
    .call(
        call
    )
}

public func call<Input, Output>(
    input: Input.Type,
    output: Output.Type = Output.self,
    _ call: @escaping @Sendable (
        Input,
        AgentToolContext
    ) async throws -> Output
) -> AgentToolDeclarationComponent where Input: Decodable & Sendable, Output: Encodable & Sendable {
    .call(
        input: input,
        output: output,
        call
    )
}

public func call<Input, Output>(
    input: Input.Type,
    output: Output.Type = Output.self,
    _ call: @escaping @Sendable (
        Input
    ) async throws -> Output
) -> AgentToolDeclarationComponent where Input: Decodable & Sendable, Output: Encodable & Sendable {
    .call(
        input: input,
        output: output,
        call
    )
}

public func call<Output>(
    output: Output.Type = Output.self,
    _ call: @escaping @Sendable (
        AgentToolContext
    ) async throws -> Output
) -> AgentToolDeclarationComponent where Output: Encodable & Sendable {
    .call(
        output: output,
        call
    )
}

public func call<Output>(
    output: Output.Type = Output.self,
    _ call: @escaping @Sendable () async throws -> Output
) -> AgentToolDeclarationComponent where Output: Encodable & Sendable {
    .call(
        output: output,
        call
    )
}

public func toolCall<Input, Output>(
    input: Input.Type,
    output: Output.Type = Output.self,
    _ call: @escaping @Sendable (
        Input,
        AgentToolContext
    ) async throws -> Output
) -> AgentToolDeclarationComponent where Input: Decodable & Sendable, Output: Encodable & Sendable {
    .call(
        input: input,
        output: output,
        call
    )
}

public func toolCall<Input, Output>(
    input: Input.Type,
    output: Output.Type = Output.self,
    _ call: @escaping @Sendable (
        Input
    ) async throws -> Output
) -> AgentToolDeclarationComponent where Input: Decodable & Sendable, Output: Encodable & Sendable {
    .call(
        input: input,
        output: output,
        call
    )
}

public func toolCall<Output>(
    output: Output.Type = Output.self,
    _ call: @escaping @Sendable (
        AgentToolContext
    ) async throws -> Output
) -> AgentToolDeclarationComponent where Output: Encodable & Sendable {
    .call(
        output: output,
        call
    )
}

public func toolCall<Output>(
    output: Output.Type = Output.self,
    _ call: @escaping @Sendable () async throws -> Output
) -> AgentToolDeclarationComponent where Output: Encodable & Sendable {
    .call(
        output: output,
        call
    )
}

public func effect<Input>(
    input: Input.Type,
    _ call: @escaping @Sendable (
        Input,
        AgentToolContext
    ) async throws -> Void
) -> AgentToolDeclarationComponent where Input: Decodable & Sendable {
    .effect(
        input: input,
        call
    )
}

public func effect<Input>(
    input: Input.Type,
    _ call: @escaping @Sendable (
        Input
    ) async throws -> Void
) -> AgentToolDeclarationComponent where Input: Decodable & Sendable {
    .effect(
        input: input,
        call
    )
}

public func effect(
    _ call: @escaping @Sendable (
        AgentToolContext
    ) async throws -> Void
) -> AgentToolDeclarationComponent {
    .effect(
        call
    )
}

public func effect(
    _ call: @escaping @Sendable () async throws -> Void
) -> AgentToolDeclarationComponent {
    .effect(
        call
    )
}

public func toolEffect<Input>(
    input: Input.Type,
    _ call: @escaping @Sendable (
        Input,
        AgentToolContext
    ) async throws -> Void
) -> AgentToolDeclarationComponent where Input: Decodable & Sendable {
    .effect(
        input: input,
        call
    )
}

public func toolEffect<Input>(
    input: Input.Type,
    _ call: @escaping @Sendable (
        Input
    ) async throws -> Void
) -> AgentToolDeclarationComponent where Input: Decodable & Sendable {
    .effect(
        input: input,
        call
    )
}

public func toolEffect(
    _ call: @escaping @Sendable (
        AgentToolContext
    ) async throws -> Void
) -> AgentToolDeclarationComponent {
    .effect(
        call
    )
}

public func toolEffect(
    _ call: @escaping @Sendable () async throws -> Void
) -> AgentToolDeclarationComponent {
    .effect(
        call
    )
}
