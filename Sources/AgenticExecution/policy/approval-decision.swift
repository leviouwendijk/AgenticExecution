public enum ApprovalDecision: String, Sendable, Codable, Hashable, CaseIterable {
    case approved
    case denied
    case skipped
    case needshuman
}

public extension ApprovalDecision {
    var isApproved: Bool {
        self == .approved
    }

    var isDenied: Bool {
        self == .denied
    }

    var isSkipped: Bool {
        self == .skipped
    }

    var requiresHumanReview: Bool {
        self == .needshuman
    }
}
