import Agentic

public struct ToolExecutionPolicy: Sendable, Codable, Hashable {
    public var autonomyMode: AutonomyMode
    public var limits: ExecutionLimits

    public init(
        autonomyMode: AutonomyMode = .review_privileged,
        limits: ExecutionLimits = .unlimited
    ) {
        self.autonomyMode = autonomyMode
        self.limits = limits
    }

    public func evaluate(
        _ preflight: ToolPreflight
    ) -> ApprovalRequirement {
        if preflight.risk == .forbidden
            || preflight.policyDirectives?.contains(
                .require_deny
            ) == true
        {
            return .denied_forbidden
        }

        let effectiveLimits = limits.merged(
            with: preflight.limits
        )

        if effectiveLimits.requiresHumanReview(
            for: preflight
        ) {
            return .needs_human_review
        }

        let requirement = autonomyRequirement(
            for: preflight.risk
        )

        guard
            requirement == .no_approval_needed,
            preflight.policyDirectives?.contains(
                .require_human_review
            ) == true
        else {
            return requirement
        }

        return .needs_human_review
    }

    public func decision(
        for preflight: ToolPreflight
    ) -> ApprovalDecision {
        evaluate(preflight).decision
    }
}

private extension ToolExecutionPolicy {
    func autonomyRequirement(
        for risk: ActionRisk
    ) -> ApprovalRequirement {
        switch autonomyMode {
        case .suggest_only:
            return .needs_human_review

        case .auto_observe:
            switch risk {
            case .observe:
                return .no_approval_needed

            case .boundedmutate, .privileged:
                return .needs_human_review

            case .forbidden:
                return .denied_forbidden
            }

        case .auto_bounded_mutate:
            switch risk {
            case .observe, .boundedmutate:
                return .no_approval_needed

            case .privileged, .forbidden:
                return .denied_forbidden
            }

        case .review_privileged:
            switch risk {
            case .observe, .boundedmutate:
                return .no_approval_needed

            case .privileged:
                return .needs_human_review

            case .forbidden:
                return .denied_forbidden
            }
        }
    }
}
