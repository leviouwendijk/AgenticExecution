import Agentic
import AgenticExecution
import TestFlows

extension AgenticExecutionFlowTesting {
    static func runToolPolicyDirectives() throws -> [TestFlowDiagnostic] {
        let observePolicy = ToolExecutionPolicy(
            autonomyMode: .auto_observe
        )

        let ordinary = ToolPreflight(
            toolName: "policy_fixture",
            risk: .observe,
            summary: "Ordinary observe fixture."
        )

        try Expect.equal(
            observePolicy.evaluate(ordinary),
            .no_approval_needed,
            "ordinary observe remains auto-approved"
        )

        let review = ToolPreflight(
            toolName: "policy_fixture",
            risk: .observe,
            summary: "Review-directed observe fixture.",
            policyDirectives: [
                .require_human_review,
            ]
        )

        try Expect.equal(
            observePolicy.evaluate(review),
            .needs_human_review,
            "review directive escalates otherwise automatic observe"
        )

        let deny = ToolPreflight(
            toolName: "policy_fixture",
            risk: .observe,
            summary: "Deny-directed observe fixture.",
            policyDirectives: [
                .require_deny,
            ]
        )

        try Expect.equal(
            observePolicy.evaluate(deny),
            .denied_forbidden,
            "deny directive rejects otherwise automatic observe"
        )

        let denyWins = ToolPreflight(
            toolName: "policy_fixture",
            risk: .observe,
            summary: "Mixed directive fixture.",
            policyDirectives: [
                .require_human_review,
                .require_deny,
            ]
        )

        try Expect.equal(
            observePolicy.evaluate(denyWins),
            .denied_forbidden,
            "deny directive takes precedence over review"
        )

        let boundedPolicy = ToolExecutionPolicy(
            autonomyMode: .auto_bounded_mutate
        )
        let privilegedReview = ToolPreflight(
            toolName: "policy_fixture",
            risk: .privileged,
            summary: "Privileged review fixture.",
            policyDirectives: [
                .require_human_review,
            ]
        )

        try Expect.equal(
            boundedPolicy.evaluate(privilegedReview),
            .denied_forbidden,
            "review directive never weakens stricter autonomy denial"
        )

        let boundedReview = ToolPreflight(
            toolName: "policy_fixture",
            risk: .boundedmutate,
            summary: "Bounded mutation review fixture.",
            policyDirectives: [
                .require_human_review,
            ]
        )

        try Expect.equal(
            boundedPolicy.evaluate(boundedReview),
            .needs_human_review,
            "review directive can tighten an otherwise automatic bounded mutation"
        )

        return [
            .field(
                "ordinary",
                observePolicy.evaluate(ordinary).rawValue
            ),
            .field(
                "review",
                observePolicy.evaluate(review).rawValue
            ),
            .field(
                "deny",
                observePolicy.evaluate(deny).rawValue
            ),
            .field(
                "privileged",
                boundedPolicy.evaluate(privilegedReview).rawValue
            ),
        ]
    }
}
