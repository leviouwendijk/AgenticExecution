import Foundation

public enum AgentToolDeclarationError: Error, Sendable, LocalizedError {
    case missingCall(String)

    public var errorDescription: String? {
        switch self {
        case .missingCall(let identifier):
            return "Tool declaration '\(identifier)' does not define a call handler."
        }
    }
}
