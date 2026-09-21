import Agentic
import AgenticExecution
import Primitives
import Schema
import TestFlows
import Workspace

extension AgenticExecutionFlowTesting {
    static func runToolReconciliation() async throws -> [TestFlowDiagnostic] {
        let applied = try await reconciliation(
            .applied
        )
        guard case .applied(let result)? = applied else {
            throw ToolReconciliationFlowError.unexpectedResult
        }

        let output = try JSONToolBridge.decode(
            ToolReconciliationFixtureOutput.self,
            from: result.result.output
        )

        try Expect.equal(
            output.value,
            "fixture-reconciled",
            "applied reconciliation preserves typed Output through registry erasure"
        )
        try Expect.equal(
            result.result.isError,
            false,
            "applied reconciliation restores the normal successful tool result contract"
        )
        try Expect.equal(
            applied?.state,
            Recovery.State(
                reconciled: .applied
            ),
            "applied reconciliation records applied/unsafe state"
        )

        let appliedWithoutOutput = try await reconciliation(
            .applied_without_output
        )
        guard case .applied_without_output? = appliedWithoutOutput else {
            throw ToolReconciliationFlowError.unexpectedResult
        }
        try Expect.equal(
            appliedWithoutOutput?.state,
            Recovery.State(
                reconciled: .applied
            ),
            "applied-without-output proves the effect happened without fabricating Output"
        )

        let notApplied = try await reconciliation(
            .not_applied
        )
        guard case .not_applied? = notApplied else {
            throw ToolReconciliationFlowError.unexpectedResult
        }
        try Expect.equal(
            notApplied?.state,
            Recovery.State(
                reconciled: .not_applied
            ),
            "not-applied reconciliation establishes safe retry state"
        )

        let unknown = try await reconciliation(
            .unknown
        )
        guard case .unknown? = unknown else {
            throw ToolReconciliationFlowError.unexpectedResult
        }
        try Expect.equal(
            unknown?.state,
            Recovery.State(
                reconciled: .unknown
            ),
            "unknown reconciliation remains requires-reconciliation"
        )

        let unsupported = try await unsupportedReconciliation()
        try Expect.equal(
            unsupported == nil,
            true,
            "AgentTool default reconciliation explicitly means unsupported"
        )

        return [
            .field(
                "applied",
                applied?.state.effect.rawValue ?? "missing"
            ),
            .field(
                "applied_without_output",
                appliedWithoutOutput?.state.effect.rawValue ?? "missing"
            ),
            .field(
                "not_applied",
                notApplied?.state.retry.rawValue ?? "missing"
            ),
            .field(
                "unknown",
                unknown?.state.retry.rawValue ?? "missing"
            ),
            .field(
                "unsupported",
                unsupported == nil ? "nil" : "unexpected"
            ),
        ]
    }
}

private enum ToolReconciliationFixtureMode: Sendable {
    case applied
    case applied_without_output
    case not_applied
    case unknown
}

private struct ToolReconciliationFixtureInput:
    Sendable,
    Codable,
    Hashable,
    JSONSchemaProviding
{
    let value: String

    static var jsonschema: JSONSchema {
        .any
    }
}

private struct ToolReconciliationFixtureOutput:
    Sendable,
    Codable,
    Hashable,
    JSONSchemaProviding
{
    let value: String

    static var jsonschema: JSONSchema {
        .any
    }
}

private struct ToolReconciliationFixture: Tool {
    typealias Input = ToolReconciliationFixtureInput
    typealias Output = ToolReconciliationFixtureOutput

    static let definition = ToolDefinition(
        identifier: "tool_reconciliation_fixture",
        purpose:
            "Exercises typed tool reconciliation through registry erasure.",
        risk: .boundedmutate
    )

    let mode: ToolReconciliationFixtureMode

    func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        _ = input
        throw ToolReconciliationFlowError.unexpectedCall
    }

    func reconcile(
        _ input: Input,
        after failure: ToolCall.Failure,
        workspace _: WorkspaceContext?
    ) async throws -> ToolCall.Reconciliation<Output>? {
        try Expect.equal(
            failure.phase,
            .call,
            "reconciliation receives the durable original call failure"
        )
        try Expect.equal(
            failure.toolCallID,
            "reconciliation-call",
            "reconciliation receives canonical call identity in the failure envelope"
        )

        switch mode {
        case .applied:
            return .applied(
                Output(
                    value: "\(input.value)-reconciled"
                )
            )

        case .applied_without_output:
            return .applied_without_output

        case .not_applied:
            return .not_applied

        case .unknown:
            return .unknown
        }
    }
}

private struct ToolReconciliationUnsupportedFixture: Tool {
    typealias Input = ToolReconciliationFixtureInput
    typealias Output = ToolReconciliationFixtureOutput

    static let definition = ToolDefinition(
        identifier:
            "tool_reconciliation_unsupported_fixture",
        purpose:
            "Exercises the default unsupported reconciliation path.",
        risk: .boundedmutate
    )

    func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        Output(
            value: input.value
        )
    }
}

private func reconciliation(
    _ mode: ToolReconciliationFixtureMode
) async throws -> RegisteredAgentTool.Reconciliation? {
    let tool = ToolReconciliationFixture(
        mode: mode
    )
    let call = try reconciliationCall(
        name: tool.identifier.rawValue
    )
    let registry = try ToolRegistry {
        tool
    }

    return try await registry.reconcile(
        call,
        failure: reconciliationFailure(
            tool: tool.identifier,
            callID: call.id
        ),
        workspace: nil
    )
}

private func unsupportedReconciliation()
    async throws -> RegisteredAgentTool.Reconciliation?
{
    let tool = ToolReconciliationUnsupportedFixture()
    let call = try reconciliationCall(
        name: tool.identifier.rawValue
    )
    let registry = try ToolRegistry {
        tool
    }

    return try await registry.reconcile(
        call,
        failure: reconciliationFailure(
            tool: tool.identifier,
            callID: call.id
        ),
        workspace: nil
    )
}

private func reconciliationCall(
    name: String
) throws -> ToolCall {
    ToolCall(
        id: "reconciliation-call",
        tool: ToolIdentifier(
            rawValue: name
        ),
        input: try JSONToolBridge.encode(
            ToolReconciliationFixtureInput(
                value: "fixture"
            )
        )
    )
}

private func reconciliationFailure(
    tool: ToolIdentifier,
    callID: String
) -> ToolCall.Failure {
    .init(
        tool: tool,
        toolCallID: callID,
        phase: .call,
        message: "mutation outcome unknown",
        errorType: "ToolReconciliationFixtureError",
        incident: Recovery.Incident(
            kind: .outcome_unknown,
            stage: .execution,
            effectState: .unknown,
            retrySafety: .requires_reconciliation,
            scope: .init(
                kind: .tool,
                identifier: tool.rawValue
            ),
            message: "mutation outcome unknown"
        )
    )
}

private enum ToolReconciliationFlowError: Error {
    case unexpectedCall
    case unexpectedResult
}
