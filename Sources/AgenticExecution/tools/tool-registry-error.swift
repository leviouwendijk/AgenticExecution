import Foundation

public enum ToolRegistryError: Error, Sendable, LocalizedError {
    case duplicateTool(String)

    public var errorDescription: String? {
        switch self {
        case .duplicateTool(let name):
            return "A tool named '\(name)' is already registered."
        }
    }
}
