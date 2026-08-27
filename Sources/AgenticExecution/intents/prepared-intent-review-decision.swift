public enum PreparedIntentReviewDecision: String, Sendable, Codable, Hashable, CaseIterable {
    case approve
    case deny
    case cancel
    case expire
}

public extension PreparedIntentReviewDecision {
    var resolvedStatus: PreparedIntentStatus {
        switch self {
        case .approve:
            return .approved

        case .deny:
            return .denied

        case .cancel:
            return .cancelled

        case .expire:
            return .expired
        }
    }
}
