import Foundation
import AgenticWorkspace

public protocol WorkspaceTargetableTool: AgentTool {}

public enum WorkspaceToolTargetingError:
    Error,
    Sendable,
    LocalizedError,
    Equatable
{
    case workspaceRequired(String)
    case unsupportedTool(String)

    public var errorDescription: String? {
        switch self {
        case .workspaceRequired(let toolName):
            return "Tool '\(toolName)' requires an Agentic workspace for workspace targeting."

        case .unsupportedTool(let toolName):
            return "Tool '\(toolName)' does not support workspace targeting."
        }
    }
}
