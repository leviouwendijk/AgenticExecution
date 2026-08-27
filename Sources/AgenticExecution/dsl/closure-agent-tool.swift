import Agentic
import AgenticWorkspace
import Primitives

public struct ClosureAgentTool: AgentTool {
    public var identifier: AgentToolIdentifier
    public var description: String
    public var inputSchema: JSONValue?
    public var risk: ActionRisk

    private var customPreflightHandler: AgentToolPreflightHandler?
    private let callHandler: AgentToolCallHandler

    public init(
        identifier: AgentToolIdentifier,
        description: String = "",
        inputSchema: JSONValue? = nil,
        risk: ActionRisk = .observe,
        preflight: AgentToolPreflightHandler? = nil,
        call: @escaping AgentToolCallHandler
    ) {
        self.identifier = identifier
        self.description = description
        self.inputSchema = inputSchema
        self.risk = risk
        self.customPreflightHandler = preflight
        self.callHandler = call
    }

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        if let customPreflightHandler {
            return try await customPreflightHandler(
                input,
                workspace
            )
        }

        return ToolPreflight(
            toolName: identifier.rawValue,
            risk: risk,
            workspaceRoot: workspace?.rootURL.path,
            summary: description,
            sideEffects: risk.defaultSideEffects
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        try await call(
            input: input,
            context: .init(
                workspace: workspace
            )
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        try await callHandler(
            input,
            context
        )
    }
}

public extension ClosureAgentTool {
    func description(
        _ description: String
    ) -> Self {
        var copy = self
        copy.description = description
        return copy
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
        var copy = self
        copy.inputSchema = inputSchema
        return copy
    }

    func risk(
        _ risk: ActionRisk
    ) -> Self {
        var copy = self
        copy.risk = risk
        return copy
    }

    func preflight(
        _ preflight: AgentToolPreflightHandler?
    ) -> Self {
        var copy = self
        copy.customPreflightHandler = preflight
        return copy
    }
}

public func tool(
    _ identifier: AgentToolIdentifier,
    description: String = "",
    inputSchema: JSONValue? = nil,
    risk: ActionRisk = .observe,
    call: @escaping AgentToolCallHandler
) -> ClosureAgentTool {
    ClosureAgentTool(
        identifier: identifier,
        description: description,
        inputSchema: inputSchema,
        risk: risk,
        call: call
    )
}

public func tool<Input, Output>(
    _ identifier: AgentToolIdentifier,
    input _: Input.Type,
    output _: Output.Type = Output.self,
    description: String = "",
    inputSchema: JSONValue? = nil,
    risk: ActionRisk = .observe,
    call: @escaping @Sendable (
        Input,
        AgentToolContext
    ) async throws -> Output
) -> ClosureAgentTool where Input: Decodable & Sendable, Output: Encodable & Sendable {
    ClosureAgentTool(
        identifier: identifier,
        description: description,
        inputSchema: inputSchema,
        risk: risk
    ) { value, context in
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

public func tool<Input, Output>(
    _ identifier: AgentToolIdentifier,
    input _: Input.Type,
    output _: Output.Type = Output.self,
    description: String = "",
    inputSchema: JSONValue? = nil,
    risk: ActionRisk = .observe,
    call: @escaping @Sendable (
        Input
    ) async throws -> Output
) -> ClosureAgentTool where Input: Decodable & Sendable, Output: Encodable & Sendable {
    ClosureAgentTool(
        identifier: identifier,
        description: description,
        inputSchema: inputSchema,
        risk: risk
    ) { value, _ in
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

public func tool<Output>(
    _ identifier: AgentToolIdentifier,
    output _: Output.Type = Output.self,
    description: String = "",
    inputSchema: JSONValue? = nil,
    risk: ActionRisk = .observe,
    call: @escaping @Sendable (
        AgentToolContext
    ) async throws -> Output
) -> ClosureAgentTool where Output: Encodable & Sendable {
    ClosureAgentTool(
        identifier: identifier,
        description: description,
        inputSchema: inputSchema,
        risk: risk
    ) { _, context in
        let output = try await call(
            context
        )

        return try JSONToolBridge.encode(
            output
        )
    }
}

public func effectTool<Input>(
    _ identifier: AgentToolIdentifier,
    input _: Input.Type,
    description: String = "",
    inputSchema: JSONValue? = nil,
    risk: ActionRisk = .boundedmutate,
    call: @escaping @Sendable (
        Input,
        AgentToolContext
    ) async throws -> Void
) -> ClosureAgentTool where Input: Decodable & Sendable {
    ClosureAgentTool(
        identifier: identifier,
        description: description,
        inputSchema: inputSchema,
        risk: risk
    ) { value, context in
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

public func effectTool<Input>(
    _ identifier: AgentToolIdentifier,
    input _: Input.Type,
    description: String = "",
    inputSchema: JSONValue? = nil,
    risk: ActionRisk = .boundedmutate,
    call: @escaping @Sendable (
        Input
    ) async throws -> Void
) -> ClosureAgentTool where Input: Decodable & Sendable {
    ClosureAgentTool(
        identifier: identifier,
        description: description,
        inputSchema: inputSchema,
        risk: risk
    ) { value, _ in
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

public func effectTool(
    _ identifier: AgentToolIdentifier,
    description: String = "",
    inputSchema: JSONValue? = nil,
    risk: ActionRisk = .boundedmutate,
    call: @escaping @Sendable (
        AgentToolContext
    ) async throws -> Void
) -> ClosureAgentTool {
    ClosureAgentTool(
        identifier: identifier,
        description: description,
        inputSchema: inputSchema,
        risk: risk
    ) { _, context in
        try await call(
            context
        )

        return try JSONToolBridge.encode(
            AgentToolEmptyOutput()
        )
    }
}
