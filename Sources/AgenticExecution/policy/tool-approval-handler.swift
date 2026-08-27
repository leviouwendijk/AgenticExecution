public protocol ToolApprovalHandler: Sendable {
    func decide(
        on preflight: ToolPreflight,
        requirement: ApprovalRequirement
    ) async throws -> ApprovalDecision

    func decide(
        on review: ToolInvocation.Review
    ) async throws -> ApprovalDecision
}

public extension ToolApprovalHandler {
    func decide(
        on preflight: ToolPreflight,
        requirement: ApprovalRequirement
    ) async throws -> ApprovalDecision {
        requirement.decision
    }

    func decide(
        on review: ToolInvocation.Review
    ) async throws -> ApprovalDecision {
        try await decide(
            on: review.preflight,
            requirement: review.requirement
        )
    }
}
