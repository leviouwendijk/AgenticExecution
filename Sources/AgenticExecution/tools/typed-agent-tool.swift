import Primitives
import Schema

/// Schema-backed contract for stateful AgentTool implementations.
///
/// This is one of the two typed tool authoring contracts. ToolRegistry captures
/// its semantic schema and typed parser once through registrationDescriptor.
public protocol TypedInstanceAgentTool:
    AgentTool
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

    var registrationDescriptor: AgentToolRegistrationDescriptor {
        .modelFacing(
            Input.self
        )
    }
}

/// Schema-backed contract for static AgentTool implementations.
///
/// StaticAgentTool remains the metadata convenience. TypedAgentTool adds one
/// concrete model-facing Input; output typing remains an implementation detail
/// of the individual tool.
public protocol TypedAgentTool:
    StaticAgentTool
{
    associatedtype Input:
        Decodable &
        Sendable &
        JSONSchemaProviding
}

public extension TypedAgentTool {
    static var semanticInputSchema: JSONSchema {
        Input.jsonschema
    }

    static var inputSchema: JSONValue? {
        semanticInputSchema.jsonvalue
    }

    var semanticInputSchema: JSONSchema {
        Self.semanticInputSchema
    }

    var registrationDescriptor: AgentToolRegistrationDescriptor {
        .modelFacing(
            Input.self
        )
    }
}

/// Compatibility spelling for static schema-backed tools migrated before the
/// typed contract cleanup. This is an alias, not another tool protocol.
public typealias StaticSchemaAgentTool = TypedAgentTool
