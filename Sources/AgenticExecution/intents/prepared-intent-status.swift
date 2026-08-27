public enum PreparedIntentStatus: String, Sendable, Codable, Hashable, CaseIterable {
    case pending_review
    case approved
    case denied
    case cancelled
    case expired
    case executed
    case execution_failed
}

public extension PreparedIntentStatus {
    var isTerminal: Bool {
        switch self {
        case .pending_review,
             .approved:
            return false

        case .denied,
             .cancelled,
             .expired,
             .executed,
             .execution_failed:
            return true
        }
    }

    var canBeReviewed: Bool {
        switch self {
        case .pending_review,
             .approved:
            return true

        case .denied,
             .cancelled,
             .expired,
             .executed,
             .execution_failed:
            return false
        }
    }

    var canBeExecuted: Bool {
        self == .approved
    }
}
