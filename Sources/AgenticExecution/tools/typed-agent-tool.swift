import Primitives
import Schema

/// An AgentTool whose model-facing input contract remains semantic until transport lowering.
public protocol SchemaBackedAgentTool:
    AgentTool
{
    var semanticInputSchema: JSONSchema { get }
}

/// Schema-backed contract for stateful/instance AgentTool implementations.
public protocol TypedInstanceAgentTool:
    SchemaBackedAgentTool
{
    associatedtype Input:
        Decodable &
        Sendable &
        JSONSchemaProviding
}

public extension TypedInstanceAgentTool {
    var semanticInputSchema: JSONSchema {
        Input.jsonschema
    }

    var inputSchema: JSONValue? {
        semanticInputSchema.jsonvalue
    }
}


/// Schema-backed contract for static tools that only need automatic input-schema projection.
public protocol StaticSchemaAgentTool:
    StaticAgentTool,
    SchemaBackedAgentTool
{
    associatedtype Input:
        Decodable &
        Sendable &
        JSONSchemaProviding
}

public extension StaticSchemaAgentTool {
    static var semanticInputSchema: JSONSchema {
        Input.jsonschema
    }

    static var inputSchema: JSONValue? {
        semanticInputSchema.jsonvalue
    }

    var semanticInputSchema: JSONSchema {
        Self.semanticInputSchema
    }
}

/// Schema-backed typed contract for static AgentTool implementations.
public protocol TypedAgentTool:
    StaticSchemaAgentTool
{
    associatedtype Output:
        Encodable &
        Sendable
}
