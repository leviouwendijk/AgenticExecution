import Foundation

public enum WorkspaceToolTargetingError:
    Error,
    Sendable,
    LocalizedError,
    Equatable
{
    case emptySubpath
    case workspaceRequired(String)
    case unsupportedTool(String)

    public var errorDescription: String? {
        switch self {
        case .emptySubpath:
            return "Workspace target subpath must not be empty."

        case .workspaceRequired(let toolName):
            return "Tool '\(toolName)' requires a workspace context for workspace targeting."

        case .unsupportedTool(let toolName):
            return "Tool '\(toolName)' does not support workspace targeting."
        }
    }
}
