public enum ApprovalRequirement: String, Sendable, Codable, Hashable, CaseIterable {
    case no_approval_needed
    case needs_human_review
    case denied_forbidden
}

public extension ApprovalRequirement {
    var requiresHumanReview: Bool {
        self == .needs_human_review
    }

    var isDenied: Bool {
        self == .denied_forbidden
    }

    var decision: ApprovalDecision {
        switch self {
        case .no_approval_needed:
            return .approved

        case .needs_human_review:
            return .needshuman

        case .denied_forbidden:
            return .denied
        }
    }
}
