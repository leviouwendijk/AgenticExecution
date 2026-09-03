import Agentic
import Foundation

public enum ToolRegistryExecutionError: Error, Sendable, LocalizedError {
    case missingTool(String)

    public var errorDescription: String? {
        switch self {
        case .missingTool(let name):
            return "No tool is registered with name '\(name)'."
        }
    }
}

public extension ToolRegistry {
    func execute(
        _ call: AgentToolCall,
        context: AgentToolExecutionContext
    ) async throws -> AgentToolResult {
        guard let registered =
            registeredTool(
                named: call.name
            )
        else {
            throw ToolRegistryExecutionError.missingTool(
                call.name
            )
        }

        return try await registered.execute(
            call,
            context: context
        )
    }
}
