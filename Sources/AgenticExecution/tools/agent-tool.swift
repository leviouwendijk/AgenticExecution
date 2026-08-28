import Agentic
import AgenticWorkspace
import Primitives

public protocol AgentTool: Sendable {
    var identifier: AgentToolIdentifier { get }
    var description: String { get }
    var inputSchema: JSONValue? { get }
    var risk: ActionRisk { get }

    func processResult(
        input: JSONValue,
        output: JSONValue,
        workspace: AgentWorkspace?
    ) -> AgentToolResultProcessing

    func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight

    func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight

    func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue

    func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue
}

public extension AgentTool {
    var inputSchema: JSONValue? {
        nil
    }

    func processResult(
        input _: JSONValue,
        output _: JSONValue,
        workspace _: AgentWorkspace?
    ) -> AgentToolResultProcessing {
        .none
    }

    var name: String {
        identifier.rawValue
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
        input _: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        ToolPreflight(
            toolName: name,
            risk: risk,
            workspaceRoot: workspace?.rootURL.path,
            summary: description,
            sideEffects: risk.defaultSideEffects
        )
    }

    func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try await preflight(
            input: input,
            workspace: context.workspace
        )
    }

    func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        try await call(
            input: input,
            workspace: context.workspace
        )
    }
}
