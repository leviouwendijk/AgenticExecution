import Agentic
import Foundation
import Workspace

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
        _ call: ToolCall,
        workspace: WorkspaceContext? = nil
    ) async throws -> AgentToolExecutionResult {
        guard let registered =
            registeredTool(
                identifiedBy: call.tool
            )
        else {
            throw ToolRegistryExecutionError.missingTool(
                call.tool.rawValue
            )
        }

        return try await registered.execute(
            call,
            workspace: workspace
        )
    }

    func reconcile(
        _ call: ToolCall,
        failure: ToolCall.Failure,
        workspace: WorkspaceContext? = nil
    ) async throws -> RegisteredAgentTool.Reconciliation? {
        guard let registered =
            registeredTool(
                identifiedBy: call.tool
            )
        else {
            throw ToolRegistryExecutionError.missingTool(
                call.tool.rawValue
            )
        }

        return try await registered.reconcile(
            call,
            failure: failure,
            workspace: workspace
        )
    }
}
