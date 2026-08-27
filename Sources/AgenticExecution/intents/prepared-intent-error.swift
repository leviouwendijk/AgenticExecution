import Agentic
import Foundation

public enum PreparedIntentError: Error, Sendable, LocalizedError {
    case durableStorageRequired
    case intentNotFound(PreparedIntentIdentifier)
    case emptyActionType
    case emptyTitle
    case emptySummary
    case emptyExecutionSummary
    case alreadyTerminal(PreparedIntentIdentifier, PreparedIntentStatus)
    case expired(PreparedIntentIdentifier)
    case notApproved(PreparedIntentIdentifier, PreparedIntentStatus)
    case executionRecordIntentMismatch(
        expected: PreparedIntentIdentifier,
        actual: PreparedIntentIdentifier
    )

    public var errorDescription: String? {
        switch self {
        case .durableStorageRequired:
            return "Prepared intent operations require durable Agentic storage."

        case .intentNotFound(let id):
            return "No prepared intent exists for id '\(id.rawValue)'."

        case .emptyActionType:
            return "Prepared intent action type cannot be empty."

        case .emptyTitle:
            return "Prepared intent review title cannot be empty."

        case .emptySummary:
            return "Prepared intent review summary cannot be empty."

        case .emptyExecutionSummary:
            return "Prepared intent execution summary cannot be empty."

        case .alreadyTerminal(let id, let status):
            return "Prepared intent '\(id.rawValue)' is already terminal with status '\(status.rawValue)'."

        case .expired(let id):
            return "Prepared intent '\(id.rawValue)' has expired."

        case .notApproved(let id, let status):
            return "Prepared intent '\(id.rawValue)' is not executable because its status is '\(status.rawValue)'."

        case .executionRecordIntentMismatch(let expected, let actual):
            return "Execution record intent id '\(actual.rawValue)' does not match prepared intent '\(expected.rawValue)'."
        }
    }
}
