import Agentic
import AgenticExecution
import AgenticWorkspace
import Primitives
import Schema
import TestFlows

extension AgenticExecutionFlowTesting {
    static func runToolCallResolver() async throws -> [TestFlowDiagnostic] {
        let probe = ToolCallResolverProbe()
        let registry = try toolCallResolverRegistry(
            probe: probe
        )

        let observeResolver = GovernedAgentToolCallResolver(
            registry: registry,
            exposure: AgentToolExposure(
                policy: .explicit(
                    [
                        "resolver_observe",
                    ]
                )
            ),
            policy: .init(
                autonomyMode: .auto_observe
            )
        )

        let observeResult = try await observeResolver.resolve(
            try toolCallResolverCall(
                id: "resolver-observe-call",
                name: "resolver_observe"
            )
        )

        try Expect.equal(
            observeResult.isError,
            false,
            "exposed observe call resolves through governed execution"
        )
        try Expect.equal(
            await probe.invocationCount(),
            1,
            "observe call executes exactly once"
        )

        do {
            _ = try await observeResolver.resolve(
                try toolCallResolverCall(
                    id: "resolver-unexposed-call",
                    name: "resolver_mutate"
                )
            )

            throw ToolCallResolverFlowFailure
                .expectedUnexposedToolRejection
        } catch AgentToolExposureError.toolNotExposed(let tool) {
            try Expect.equal(
                tool,
                "resolver_mutate",
                "resolver rejects registered but unexposed model calls"
            )
        }

        try Expect.equal(
            await probe.invocationCount(),
            1,
            "unexposed call never reaches execution"
        )

        let approvedResolver = GovernedAgentToolCallResolver(
            registry: registry,
            exposure: AgentToolExposure(
                policy: .explicit(
                    [
                        "resolver_mutate",
                    ]
                )
            ),
            policy: .init(
                autonomyMode: .auto_observe
            ),
            approvalHandler: ToolCallResolverApprovalHandler(
                decision: .approved
            )
        )

        let approvedResult = try await approvedResolver.resolve(
            try toolCallResolverCall(
                id: "resolver-approved-call",
                name: "resolver_mutate"
            )
        )

        try Expect.equal(
            approvedResult.isError,
            false,
            "in-process human approval returns the executed tool result"
        )
        try Expect.equal(
            await probe.invocationCount(),
            2,
            "approved bounded mutation executes exactly once"
        )

        let unresolvedResolver = GovernedAgentToolCallResolver(
            registry: registry,
            exposure: AgentToolExposure(
                policy: .explicit(
                    [
                        "resolver_mutate",
                    ]
                )
            ),
            policy: .init(
                autonomyMode: .auto_observe
            )
        )

        do {
            _ = try await unresolvedResolver.resolve(
                try toolCallResolverCall(
                    id: "resolver-needs-human-call",
                    name: "resolver_mutate"
                )
            )

            throw ToolCallResolverFlowFailure
                .expectedNeedsHumanReview
        } catch AgentToolCallResolutionError.needsHumanReview(let review) {
            try Expect.equal(
                review.requirement,
                .needs_human_review,
                "resolver preserves unresolved human review for durable fallback"
            )
            try Expect.equal(
                review.call.name,
                "resolver_mutate",
                "resolver preserves the pending tool call"
            )
        }

        try Expect.equal(
            await probe.invocationCount(),
            2,
            "unresolved human review never executes the tool"
        )

        let deniedResolver = GovernedAgentToolCallResolver(
            registry: registry,
            exposure: AgentToolExposure(
                policy: .explicit(
                    [
                        "resolver_mutate",
                    ]
                )
            ),
            policy: .init(
                autonomyMode: .auto_observe
            ),
            approvalHandler: ToolCallResolverApprovalHandler(
                decision: .denied
            )
        )

        let deniedResult = try await deniedResolver.resolve(
            try toolCallResolverCall(
                id: "resolver-denied-call",
                name: "resolver_mutate"
            )
        )

        try Expect.equal(
            deniedResult.isError,
            true,
            "denial becomes a terminal model-facing error result"
        )
        try Expect.equal(
            await probe.invocationCount(),
            2,
            "denial never executes the tool"
        )

        return [
            .field(
                "cases",
                "observe,exposure,approved,needshuman,denied"
            ),
            .field(
                "executions",
                "\(await probe.invocationCount())"
            ),
        ]
    }
}

private actor ToolCallResolverProbe {
    private var count = 0

    func recordInvocation() {
        count += 1
    }

    func invocationCount() -> Int {
        count
    }
}

private struct ToolCallResolverProbeInput:
    Sendable,
    Codable,
    JSONSchemaProviding
{
    static var jsonschema: JSONSchema {
        .object {}
    }
}

private struct ToolCallResolverProbeTool:
    AgentTool
{
    typealias Input = ToolCallResolverProbeInput
    typealias Output = ToolCallResolverProbeInput

    let identifier: AgentToolIdentifier
    let description: String
    let risk: ActionRisk
    let probe: ToolCallResolverProbe

    func call(
        _ input: Input,
        context _: AgentToolExecutionContext
    ) async throws -> Output {
        await probe.recordInvocation()
        return input
    }
}

private struct ToolCallResolverApprovalHandler:
    ToolApprovalHandler
{
    let decision: ApprovalDecision

    func decide(
        on review: ToolInvocation.Review
    ) async throws -> ApprovalDecision {
        decision
    }
}

private enum ToolCallResolverFlowFailure:
    Error
{
    case expectedUnexposedToolRejection
    case expectedNeedsHumanReview
}

private func toolCallResolverRegistry(
    probe: ToolCallResolverProbe
) throws -> ToolRegistry {
    var registry = ToolRegistry()

    try registry.register(
        ToolCallResolverProbeTool(
            identifier: "resolver_observe",
            description: "Observe resolver fixture.",
            risk: .observe,
            probe: probe
        )
    )
    try registry.register(
        ToolCallResolverProbeTool(
            identifier: "resolver_mutate",
            description: "Bounded mutation resolver fixture.",
            risk: .boundedmutate,
            probe: probe
        )
    )

    return registry
}

private func toolCallResolverCall(
    id: String,
    name: String
) throws -> AgentToolCall {
    AgentToolCall(
        id: id,
        name: name,
        input: try JSONToolBridge.encode(
            ToolCallResolverProbeInput()
        )
    )
}
