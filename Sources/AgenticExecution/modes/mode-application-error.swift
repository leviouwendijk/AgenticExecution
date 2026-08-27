import Foundation

public enum ModeApplicationError: Error, Sendable, LocalizedError {
    case missingTool(String)

    public var errorDescription: String? {
        switch self {
        case .missingTool(let identifier):
            return "Mode application requires missing tool '\(identifier)'."
        }
    }
}
