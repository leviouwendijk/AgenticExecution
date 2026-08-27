import AgenticWorkspace
import Primitives

public typealias AgentToolPreflightHandler = @Sendable (
    JSONValue,
    AgentWorkspace?
) async throws -> ToolPreflight

public typealias AgentToolCallHandler = @Sendable (
    JSONValue,
    AgentToolContext
) async throws -> JSONValue
