import Foundation

public enum ToolRegistryError: Error, Sendable, LocalizedError {
    case duplicateTool(String)
    case missingModelFacingTool(String)

    public var errorDescription: String? {
        switch self {
        case .duplicateTool(let name):
            return "A tool named '\(name)' is already registered."

        case .missingModelFacingTool(let name):
            return "No registered model-facing tool has identifier '\(name)'."
        }
    }
}
