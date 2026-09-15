import Agentic
import AgenticExecution
import AgenticRecovery
import Primitives
import Schema
import TestFlows

extension AgenticExecutionFlowTesting {
    static func runToolMechanicalObserveRetry() async throws -> [TestFlowDiagnostic] {
        let execution = try await mechanicalRecoveryExecution(
            scenario: .observe_retry
        )

        try Expect.equal(
            execution.result.isError,
            false,
            "safe observe failure is mechanically retried"
        )
        try Expect.equal(
            execution.recovery?.outcome,
            .recovered,
            "safe observe retry records recovered outcome"
        )
        try Expect.equal(
            execution.recovery?.attempts.count,
            1,
            "safe observe retry records exactly one recovery attempt"
        )
        try Expect.equal(
            execution.recovery?.attempts.first?.action,
            .retry_same_operation,
            "safe observe recovery records retry_same_operation"
        )

        let output = try JSONToolBridge.decode(
            MechanicalRecoveryOutput.self,
            from: execution.result.output
        )

        try Expect.equal(
            output.value,
            "observe-retried",
            "retry returns the ordinary typed tool output"
        )

        return [
            .field(
                "outcome",
                execution.recovery?.outcome.rawValue ?? "missing"
            ),
            .field(
                "attempts",
                "\(execution.recovery?.attempts.count ?? 0)"
            ),
        ]
    }

    static func runToolMechanicalMutationRecovery() async throws -> [TestFlowDiagnostic] {
        let applied = try await mechanicalRecoveryExecution(
            scenario: .mutation_applied
        )
        try Expect.equal(
            applied.result.isError,
            false,
            "reconciliation that proves applied and reconstructs output restores ordinary success"
        )
        try Expect.equal(
            applied.recovery?.outcome,
            .recovered,
            "applied reconciliation records recovered outcome"
        )
        try Expect.equal(
            applied.recovery?.state.effect,
            .applied,
            "applied reconciliation records applied effect"
        )

        let appliedWithoutOutput = try await mechanicalRecoveryExecution(
            scenario: .mutation_applied_without_output
        )
        try Expect.equal(
            appliedWithoutOutput.result.isError,
            true,
            "applied_without_output never fabricates successful output"
        )
        try Expect.equal(
            appliedWithoutOutput.recovery?.outcome,
            .failed,
            "applied_without_output keeps the operation failed"
        )
        try Expect.equal(
            appliedWithoutOutput.recovery?.state.effect,
            .applied,
            "failed operation still preserves confirmed applied effect"
        )

        let notApplied = try await mechanicalRecoveryExecution(
            scenario: .mutation_not_applied
        )
        try Expect.equal(
            notApplied.result.isError,
            false,
            "not-applied reconciliation permits authored same-operation retry"
        )
        try Expect.equal(
            notApplied.recovery?.outcome,
            .recovered,
            "successful mutation retry records recovered outcome"
        )
        try Expect.equal(
            notApplied.recovery?.attempts.map(\.action),
            [
                .reconcile,
                .retry_same_operation,
            ],
            "mutation recovery records reconciliation before retry"
        )

        let unresolved = try await mechanicalRecoveryExecution(
            scenario: .mutation_unknown
        )
        try Expect.equal(
            unresolved.result.isError,
            true,
            "unknown mutation effect is never blindly retried"
        )
        try Expect.equal(
            unresolved.recovery?.outcome,
            .exhausted,
            "unresolved reconciliation exhausts rather than advancing to retry"
        )
        try Expect.equal(
            unresolved.recovery?.attempts.map(\.action),
            [
                .reconcile,
            ],
            "unknown effect records only reconciliation"
        )

        let changedPreflight = try await mechanicalRecoveryExecution(
            scenario: .mutation_preflight_changed
        )
        try Expect.equal(
            changedPreflight.result.isError,
            true,
            "changed mutation preflight blocks same-operation retry"
        )
        try Expect.equal(
            changedPreflight.recovery?.outcome,
            .failed,
            "changed preflight terminates mechanical recovery as failure"
        )
        try Expect.equal(
            changedPreflight.recovery?.attempts.map(\.action),
            [
                .reconcile,
                .retry_same_operation,
            ],
            "changed-preflight failure is recorded on the authored retry step"
        )

        return [
            .field(
                "applied",
                applied.recovery?.outcome.rawValue ?? "missing"
            ),
            .field(
                "applied_without_output",
                appliedWithoutOutput.recovery?.outcome.rawValue ?? "missing"
            ),
            .field(
                "not_applied",
                notApplied.recovery?.outcome.rawValue ?? "missing"
            ),
            .field(
                "unknown",
                unresolved.recovery?.outcome.rawValue ?? "missing"
            ),
            .field(
                "changed_preflight",
                changedPreflight.recovery?.outcome.rawValue ?? "missing"
            ),
        ]
    }
}

private extension AgenticExecutionFlowTesting {
    static func mechanicalRecoveryExecution(
        scenario: MechanicalRecoveryScenario
    ) async throws -> AgentToolExecutionResult {
        let probe = MechanicalRecoveryProbe()
        let tool = MechanicalRecoveryTool(
            probe: probe
        )
        let invoker = ToolInvoker(
            registry: try ToolRegistry {
                tool
            },
            policy: ToolExecutionPolicy(
                autonomyMode: .auto_observe
            ),
            recovery: mechanicalRecoveryPolicy
        )
        let call = AgentToolCall(
            id: "mechanical-recovery-\(scenario.rawValue)",
            name: tool.identifier.rawValue,
            input: try JSONToolBridge.encode(
                MechanicalRecoveryInput(
                    scenario: scenario.rawValue
                )
            )
        )
        let review = try await invoker.review(
            call
        )

        return try await invoker.executeApproved(
            call,
            preflight: review.preflight
        )
    }

    static var mechanicalRecoveryPolicy: Recovery.Policy {
        Recovery.Policy(
            rules: [
                .init(
                    match: .init(
                        kind: .transport_transient,
                        stage: .execution,
                        scope: .tool,
                        effectState: Recovery.EffectState.none,
                        retrySafety: .safe
                    ),
                    plan: .init(
                        steps: [
                            .init(
                                action: .retry_same_operation,
                                limit: .once
                            ),
                        ]
                    )
                ),
                .init(
                    match: .init(
                        kind: .outcome_unknown,
                        stage: .execution,
                        scope: .tool,
                        effectState: .unknown,
                        retrySafety: .requires_reconciliation
                    ),
                    plan: .init(
                        steps: [
                            .init(
                                action: .reconcile,
                                limit: .once
                            ),
                            .init(
                                action: .retry_same_operation,
                                limit: .once
                            ),
                        ]
                    )
                ),
            ]
        )
    }
}

private enum MechanicalRecoveryScenario: String, Sendable {
    case observe_retry
    case mutation_applied
    case mutation_applied_without_output
    case mutation_not_applied
    case mutation_unknown
    case mutation_preflight_changed

    var risk: ActionRisk {
        switch self {
        case .observe_retry:
            .observe

        case .mutation_applied,
             .mutation_applied_without_output,
             .mutation_not_applied,
             .mutation_unknown,
             .mutation_preflight_changed:
            .boundedmutate
        }
    }
}

private struct MechanicalRecoveryInput:
    Sendable,
    Codable,
    JSONSchemaProviding
{
    let scenario: String

    static var jsonschema: JSONSchema {
        .any
    }
}

private struct MechanicalRecoveryOutput:
    Sendable,
    Codable
{
    let value: String
}

private enum MechanicalRecoveryFixtureError: Error {
    case transient
    case uncertainMutation
}

private actor MechanicalRecoveryProbe {
    private var calls: [String: Int] = [:]
    private var preflights: [String: Int] = [:]

    func nextCall(
        for scenario: String
    ) -> Int {
        let next = (calls[scenario] ?? 0) + 1
        calls[scenario] = next
        return next
    }

    func nextPreflight(
        for scenario: String
    ) -> Int {
        let next = (preflights[scenario] ?? 0) + 1
        preflights[scenario] = next
        return next
    }
}

private struct MechanicalRecoveryTool: AgentTool {
    typealias Input = MechanicalRecoveryInput
    typealias Output = MechanicalRecoveryOutput

    let identifier: AgentToolIdentifier = "mechanical_recovery_fixture"
    let description = "Exercises canonical mechanical tool recovery."
    let risk: ActionRisk = .boundedmutate
    let probe: MechanicalRecoveryProbe

    func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let scenario = try scenario(
            from: input
        )
        let number = await probe.nextPreflight(
            for: input.scenario
        )
        let summary: String

        if scenario == .mutation_preflight_changed,
           number > 1
        {
            summary = "changed mechanical recovery preflight"
        } else {
            summary = "stable mechanical recovery preflight"
        }

        return ToolPreflight(
            toolName: identifier.rawValue,
            risk: scenario.risk,
            workspaceRoot: context.workspace?.rootURL.path,
            summary: summary,
            sideEffects: scenario.risk.defaultSideEffects
        )
    }

    func call(
        _ input: Input,
        context _: AgentToolExecutionContext
    ) async throws -> Output {
        let scenario = try scenario(
            from: input
        )
        let call = await probe.nextCall(
            for: input.scenario
        )

        switch scenario {
        case .observe_retry:
            guard call > 1 else {
                throw MechanicalRecoveryFixtureError.transient
            }

            return .init(
                value: "observe-retried"
            )

        case .mutation_not_applied,
             .mutation_preflight_changed:
            guard call > 1 else {
                throw MechanicalRecoveryFixtureError.uncertainMutation
            }

            return .init(
                value: "mutation-retried"
            )

        case .mutation_applied,
             .mutation_applied_without_output,
             .mutation_unknown:
            throw MechanicalRecoveryFixtureError.uncertainMutation
        }
    }

    func classify(
        _ error: any Error,
        phase: AgentToolCallPhase,
        input: Input?,
        context _: AgentToolExecutionContext
    ) -> Recovery.Incident? {
        guard
            phase == .call,
            let input,
            let scenario = MechanicalRecoveryScenario(
                rawValue: input.scenario
            )
        else {
            return nil
        }

        switch scenario {
        case .observe_retry:
            guard error is MechanicalRecoveryFixtureError else {
                return nil
            }

            return Recovery.Incident(
                kind: .transport_transient,
                stage: .execution,
                effectState: .none,
                retrySafety: .safe,
                scope: .init(
                    kind: .tool,
                    identifier: identifier.rawValue
                ),
                message: "fixture observe transient failure"
            )

        case .mutation_applied,
             .mutation_applied_without_output,
             .mutation_not_applied,
             .mutation_unknown,
             .mutation_preflight_changed:
            guard error is MechanicalRecoveryFixtureError else {
                return nil
            }

            return Recovery.Incident(
                kind: .outcome_unknown,
                stage: .execution,
                effectState: .unknown,
                retrySafety: .requires_reconciliation,
                scope: .init(
                    kind: .tool,
                    identifier: identifier.rawValue
                ),
                message: "fixture mutation outcome is initially unknown"
            )
        }
    }

    func reconcile(
        _ input: Input,
        after failure: AgentToolCallFailure,
        context _: AgentToolExecutionContext
    ) async throws -> AgentToolReconciliation<Output>? {
        _ = failure

        switch try scenario(
            from: input
        ) {
        case .observe_retry:
            return nil

        case .mutation_applied:
            return .applied(
                .init(
                    value: "mutation-reconciled"
                )
            )

        case .mutation_applied_without_output:
            return .applied_without_output

        case .mutation_not_applied,
             .mutation_preflight_changed:
            return .not_applied

        case .mutation_unknown:
            return .unknown
        }
    }

    private func scenario(
        from input: Input
    ) throws -> MechanicalRecoveryScenario {
        guard let scenario = MechanicalRecoveryScenario(
            rawValue: input.scenario
        ) else {
            throw MechanicalRecoveryFixtureError.transient
        }

        return scenario
    }
}
