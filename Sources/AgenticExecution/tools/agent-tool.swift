import Agentic
import AgenticWorkspace
import Primitives
import Schema

/// Strongly typed author-facing contract for one Agentic tool.
///
/// Concrete tools stay in their semantic Input/Output domain. JSONValue only
/// appears after registration at provider, transcript, checkpoint, and registry
/// execution boundaries.
public protocol AgentTool<Input, Output>: Sendable {
    associatedtype Input:
        Decodable &
        Sendable &
        JSONSchemaProviding

    associatedtype Output:
        Encodable &
        Sendable

    var identifier: AgentToolIdentifier { get }
    var description: String { get }
    var risk: ActionRisk { get }
    var modelContract: AgentToolModelContract { get }
    var execution: AgentToolExecutionContract { get }

    func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight

    func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output

    func process(
        _ output: Output,
        input: Input,
        context: AgentToolExecutionContext
    ) -> AgentToolResultProjection?
}

public extension AgentTool {
    var name: String {
        identifier.rawValue
    }

    var semanticInputSchema: JSONSchema {
        Input.jsonschema
    }

    var inputSchema: JSONValue {
        semanticInputSchema.jsonvalue
    }

    var modelContract: AgentToolModelContract {
        .modelFacing(
            inputSchema: semanticInputSchema
        )
    }

    var execution: AgentToolExecutionContract {
        .fixed
    }

    var definition: AgentToolDefinition {
        .init(
            identifier: identifier,
            description: description,
            inputSchema: inputSchema,
            risk: risk
        )
    }

    func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = input

        return ToolPreflight(
            toolName: name,
            risk: risk,
            workspaceRoot: context.workspace?.rootURL.path,
            summary: description,
            sideEffects: risk.defaultSideEffects
        )
    }

    func process(
        _ output: Output,
        input: Input,
        context: AgentToolExecutionContext
    ) -> AgentToolResultProjection? {
        _ = output
        _ = input
        _ = context
        return nil
    }
}

public extension AgentToolReference {
    static func tool<T>(
        _ tool: T,
        owner: String? = nil
    ) -> Self where T: AgentTool {
        .init(
            identifier: tool.identifier,
            owner: owner
        )
    }
}
