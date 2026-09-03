import Agentic
import AgenticExecution
import AgenticWorkspace
import Primitives
import Schema
import TestFlows

extension AgenticExecutionFlowTesting {
    static func runToolCallResolverObserver()
        async throws
        -> [TestFlowDiagnostic]
    {
        let probe = ToolCallResolverObserverProbe()
        let observer = ToolCallResolverObserverStore()
        let registry = try toolCallResolverObserverRegistry(
            probe: probe
        )

        let observeResolver = GovernedAgentToolCallResolver(
            registry: registry,
            exposure: AgentToolExposure(
                policy: .explicit(
                    [
                        "resolver_observer_observe",
                    ]
                )
            ),
            policy: .init(
                autonomyMode: .auto_observe
            ),
            resolutionObserver: { invocation in
                await observer.append(
                    invocation
                )
            }
        )

        _ = try await observeResolver.resolve(
            try toolCallResolverObserverCall(
                id: "resolver-observer-observe-call",
                name: "resolver_observer_observe"
            )
        )

        let observedExecution = try Expect.notNil(
            await observer.last(),
            "resolver observer receives completed invocation"
        )

        try Expect.equal(
            observedExecution.decision,
            .approved,
            "resolver observer sees approved invocation"
        )
        try Expect.equal(
            observedExecution.toolResult?.toolCallID,
            "resolver-observer-observe-call",
            "resolver observer sees the exact executed result"
        )
        try Expect.equal(
            await probe.invocationCount(),
            1,
            "observer does not alter normal execution"
        )

        await observer.removeAll()

        let reviewResolver = GovernedAgentToolCallResolver(
            registry: registry,
            exposure: AgentToolExposure(
                policy: .explicit(
                    [
                        "resolver_observer_mutate",
                    ]
                )
            ),
            policy: .init(
                autonomyMode: .auto_observe
            ),
            resolutionObserver: { invocation in
                await observer.append(
                    invocation
                )
            }
        )

        do {
            _ = try await reviewResolver.resolve(
                try toolCallResolverObserverCall(
                    id: "resolver-observer-review-call",
                    name: "resolver_observer_mutate"
                )
            )

            throw ToolCallResolverObserverFailure
                .expectedNeedsHumanReview
        } catch AgentToolCallResolutionError.needsHumanReview(_) {
        }

        let observedReview = try Expect.notNil(
            await observer.last(),
            "resolver observer receives unresolved review invocation"
        )

        try Expect.equal(
            observedReview.decision,
            .needshuman,
            "resolver observer sees unresolved human review"
        )
        try Expect.equal(
            observedReview.toolResult,
            nil,
            "unresolved human review remains unexecuted"
        )
        try Expect.equal(
            await probe.invocationCount(),
            1,
            "unresolved review does not execute the mutation"
        )

        return [
            .field(
                "completed_decision",
                observedExecution.decision.rawValue
            ),
            .field(
                "review_decision",
                observedReview.decision.rawValue
            ),
        ]
    }
}

private actor ToolCallResolverObserverStore {
    private var invocations: [ToolInvocation.Result] = []

    func append(
        _ invocation: ToolInvocation.Result
    ) {
        invocations.append(
            invocation
        )
    }

    func last() -> ToolInvocation.Result? {
        invocations.last
    }

    func removeAll() {
        invocations.removeAll()
    }
}

private actor ToolCallResolverObserverProbe {
    private var count = 0

    func recordInvocation() {
        count += 1
    }

    func invocationCount() -> Int {
        count
    }
}

private struct ToolCallResolverObserverInput:
    Sendable,
    Codable,
    JSONSchemaProviding
{
    static var jsonschema: JSONSchema {
        .object {}
    }
}

private struct ToolCallResolverObserverTool:
    AgentTool
{
    typealias Input = ToolCallResolverObserverInput
    typealias Output = ToolCallResolverObserverInput

    let identifier: AgentToolIdentifier
    let description: String
    let risk: ActionRisk
    let probe: ToolCallResolverObserverProbe

    func call(
        _ input: Input,
        context _: AgentToolExecutionContext
    ) async throws -> Output {
        await probe.recordInvocation()
        return input
    }
}

private enum ToolCallResolverObserverFailure:
    Error
{
    case expectedNeedsHumanReview
}

private func toolCallResolverObserverRegistry(
    probe: ToolCallResolverObserverProbe
) throws -> ToolRegistry {
    var registry = ToolRegistry()

    try registry.register(
        ToolCallResolverObserverTool(
            identifier: "resolver_observer_observe",
            description: "Observe resolver observer fixture.",
            risk: .observe,
            probe: probe
        )
    )
    try registry.register(
        ToolCallResolverObserverTool(
            identifier: "resolver_observer_mutate",
            description: "Mutate resolver observer fixture.",
            risk: .boundedmutate,
            probe: probe
        )
    )

    return registry
}

private func toolCallResolverObserverCall(
    id: String,
    name: String
) throws -> AgentToolCall {
    AgentToolCall(
        id: id,
        name: name,
        input: try JSONToolBridge.encode(
            ToolCallResolverObserverInput()
        )
    )
}
