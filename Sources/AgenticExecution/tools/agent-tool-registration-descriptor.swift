import Agentic
import Foundation
import Primitives
import Schema

/// Model-facing registration state captured once when a tool enters ToolRegistry.
public enum AgentToolModelContract:
    Sendable
{
    case modelFacing(
        inputSchema: JSONSchema
    )

    case hostOnly

    public var semanticInputSchema: JSONSchema? {
        switch self {
        case .modelFacing(let inputSchema):
            inputSchema

        case .hostOnly:
            nil
        }
    }

    public var isModelFacing: Bool {
        switch self {
        case .modelFacing:
            true

        case .hostOnly:
            false
        }
    }
}

/// A parsed input can only be produced by the parser captured for one registered tool.
public struct ParsedAgentToolInput:
    Sendable
{
    public let jsonValue: JSONValue

    init(
        jsonValue: JSONValue
    ) {
        self.jsonValue = jsonValue
    }
}

/// Registration facts supplied by AgentTool and captured by ToolRegistry.
///
/// Typed tool contracts parse through their concrete Input type. Plain AgentTool
/// implementations are host-only by default rather than being implicitly exposed
/// with an unverified schema.
public struct AgentToolRegistrationDescriptor:
    Sendable
{
    public let modelContract: AgentToolModelContract

    private let parseInputHandler:
        @Sendable (JSONValue) throws -> ParsedAgentToolInput

    init(
        modelContract: AgentToolModelContract,
        parseInput:
            @escaping @Sendable (JSONValue) throws -> ParsedAgentToolInput
    ) {
        self.modelContract = modelContract
        self.parseInputHandler = parseInput
    }

    public static var hostOnly: Self {
        .init(
            modelContract: .hostOnly
        ) { value in
            ParsedAgentToolInput(
                jsonValue: value
            )
        }
    }

    public static func modelFacing<Input>(
        _ input: Input.Type
    ) -> Self
    where
        Input:
            Decodable &
            Sendable &
            JSONSchemaProviding
    {
        .init(
            modelContract: .modelFacing(
                inputSchema: Input.jsonschema
            )
        ) { value in
            _ = try JSONToolBridge.decode(
                Input.self,
                from: value
            )

            return ParsedAgentToolInput(
                jsonValue: value
            )
        }
    }

    public func parseModelInput(
        _ input: JSONValue
    ) throws -> ParsedAgentToolInput {
        guard modelContract.isModelFacing else {
            throw AgentToolRegistrationError.hostOnly
        }

        return try parseInputHandler(
            input
        )
    }
}

public enum AgentToolRegistrationError:
    Error,
    Sendable,
    LocalizedError
{
    case hostOnly

    public var errorDescription: String? {
        switch self {
        case .hostOnly:
            "This registered AgentTool is host-only and is not exposed to model invocation."
        }
    }
}
