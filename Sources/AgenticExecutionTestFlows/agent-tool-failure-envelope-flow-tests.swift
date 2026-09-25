import Agentic
import AgenticExecution
import Foundation
import Primitives
import Schema
import TestFlows
import Workspace

extension AgenticExecutionFlowTesting {
    static func runToolCallFailureEnvelope() async throws -> [TestDiagnostic] {
        try await provePhase(
            .decode,
            tool: PhaseFailureTool<PhaseFailureDecodeIdentity>(
                failurePhase: .call
            ),
            call: ToolCall(
                id: "phase-failure-decode-call",
                tool: ToolIdentifier(
                    rawValue: "phase_failure_decode"
                ),
                input: .object([:])
            ),
            operation: .execute
        )

        try await provePhase(
            .preflight,
            tool: PhaseFailureTool<PhaseFailurePreflightIdentity>(
                failurePhase: .preflight
            ),
            call: try phaseCall(
                id: "phase-failure-preflight-call",
                name: "phase_failure_preflight"
            ),
            operation: .preflight
        )

        try await provePhase(
            .call,
            tool: PhaseFailureTool<PhaseFailureCallIdentity>(
                failurePhase: .call
            ),
            call: try phaseCall(
                id: "phase-failure-call-call",
                name: "phase_failure_call"
            ),
            operation: .execute
        )

        try await provePhase(
            .process,
            tool: PhaseFailureTool<PhaseFailureProcessIdentity>(
                failurePhase: .process
            ),
            call: try phaseCall(
                id: "phase-failure-process-call",
                name: "phase_failure_process"
            ),
            operation: .execute
        )

        try await proveEncodePhase()
        try await proveReportedFailureResult()
        try await proveToolPlanFailurePersistence()
        let recoveryEvidence =
            try await proveRecoveryErrorEvidence()

        return [
            .field(
                "phases",
                ToolCall.Phase.allCases
                    .map(\.rawValue)
                    .joined(separator: ",")
            ),
            .field(
                "reported-failure",
                "typed"
            ),
            .field(
                "tool-plan-persistence",
                "typed"
            ),
            .field(
                "recovery-error-evidence",
                String(recoveryEvidence)
            ),
        ]
    }
}

private enum PhaseFailureOperation {
    case preflight
    case execute
}

private func provePhase<T: Tool>(
    _ expectedPhase: ToolCall.Phase,
    tool: T,
    call: ToolCall,
    operation: PhaseFailureOperation
) async throws {
    let registry = try ToolRegistry {
        tool
    }

    let failure = try await capturedFailure {
        switch operation {
        case .preflight:
            _ = try await registry.preflight(
                call,
                workspace: nil
            )

        case .execute:
            _ = try await registry.execute(
                call,
                workspace: nil
            )
        }
    }

    try Expect.equal(
        failure.phase,
        expectedPhase,
        "\(expectedPhase.rawValue) failure retains its execution phase"
    )
    try Expect.equal(
        failure.tool,
        tool.identifier,
        "\(expectedPhase.rawValue) failure retains the registered tool"
    )
    try Expect.equal(
        failure.toolCallID,
        call.id,
        "\(expectedPhase.rawValue) failure retains the tool call id"
    )
}

private func proveEncodePhase() async throws {
    let tool = EncodeFailureTool()
    let registry = try ToolRegistry {
        tool
    }
    let call = try phaseCall(
        id: "phase-failure-encode-call",
        name: tool.identifier.rawValue
    )
    let failure = try await capturedFailure {
        _ = try await registry.execute(
            call,
            workspace: nil
        )
    }

    try Expect.equal(
        failure.phase,
        .encode,
        "output encoding failures retain the encode phase"
    )
    try Expect.equal(
        failure.toolCallID,
        call.id,
        "encode failure retains the tool call id"
    )
}

private func proveReportedFailureResult() async throws {
    let tool = ReportedFailureTool()
    let registry = try ToolRegistry {
        tool
    }
    let call = try phaseCall(
        id: "typed-reported-failure-call",
        name: tool.identifier.rawValue
    )

    let result = try await registry.execute(
        call,
        workspace: nil
    )
    let output = try JSONToolBridge.decode(
        PhaseFailureOutput.self,
        from: result.result.output
    )
    let projection = try Expect.notNil(
        result.result.projection,
        "reported failure still runs typed process"
    )

    try Expect.true(
        result.result.isError,
        "typed reported failure becomes a model-visible error result"
    )
    try Expect.equal(
        output.value,
        "reported",
        "typed reported failure is encoded only at the registered boundary"
    )
    try Expect.equal(
        projection.status,
        "failed",
        "reported failure retains its semantic projection"
    )
}

private func proveToolPlanFailurePersistence() async throws {
    let tool = PhaseFailureTool<PhaseFailurePlanIdentity>(
        failurePhase: .call
    )
    let invoker = ToolInvoker(
        registry: try ToolRegistry {
            tool
        },
        policy: ToolExecutionPolicy(
            autonomyMode: .auto_observe
        )
    )
    let call = try phaseCall(
        id: "phase-failure-plan-call",
        name: tool.identifier.rawValue
    )
    let plan = try ToolPlan(
        id: "phase-failure-plan",
        root: .call(
            call
        )
    )
    let run = try await ToolPlan.RunExecutor(
        invoker: invoker
    ).start(
        plan,
        executionPolicy: .single_step
    )
    let persisted = try JSONDecoder().decode(
        ToolPlan.Run.self,
        from: JSONEncoder().encode(
            run
        )
    )
    let record = try Expect.notNil(
        persisted.attempts.first?
            .result.records.first,
        "ToolPlan attempt persists the failed record"
    )
    let failure = try Expect.notNil(
        record.toolFailure,
        "ToolPlan record persists the typed tool failure"
    )
    let executionFailure = try Expect.notNil(
        record.invocation?.execution?.failure,
        "ToolPlan invocation persists the canonical typed tool failure"
    )

    try Expect.equal(
        executionFailure,
        failure,
        "ToolPlan projection preserves the exact canonical execution failure"
    )
    try Expect.equal(
        failure.phase,
        .call,
        "single-step remapping preserves the typed tool failure"
    )
    try Expect.equal(
        failure.toolCallID,
        call.id,
        "durable ToolPlan history preserves the failed call id"
    )
}

private func proveRecoveryErrorEvidence() async throws -> Bool {
    let tool = RecoveryFailureTool()
    let call = try phaseCall(
        id: "recovery-error-evidence-call",
        name: tool.identifier.rawValue
    )
    let registry = try ToolRegistry {
        tool
    }
    let failure = try await capturedFailure {
        _ = try await registry.execute(
            call,
            workspace: nil
        )
    }

    try Expect.equal(
        failure.phase,
        .call,
        "classified recovery failure retains its concrete tool phase"
    )
    try Expect.equal(
        failure.message,
        "fixture call failure",
        "tool failure envelope retains the underlying presentation message"
    )

    let incident = try Expect.notNil(
        failure.incident,
        "classified tool failure retains a normalized recovery incident"
    )

    try Expect.equal(
        incident.kind,
        .transport_transient,
        "tool classifier retains normalized recovery kind"
    )
    try Expect.equal(
        incident.stage,
        .execution,
        "tool classifier retains normalized recovery stage"
    )
    try Expect.equal(
        incident.effectState,
        .none,
        "tool classifier retains effect-state semantics"
    )
    try Expect.equal(
        incident.retrySafety,
        .safe,
        "tool classifier retains retry-safety semantics"
    )
    try Expect.equal(
        incident.scope.kind,
        .tool,
        "tool classifier retains tool recovery scope"
    )
    try Expect.equal(
        incident.message,
        "fixture classified tool failure",
        "operational recovery message remains distinct from the underlying diagnostic message"
    )
    try Expect.equal(
        failure.toolCallID,
        call.id,
        "canonical failure envelope carries the tool call identity independently of classification"
    )
    try Expect.equal(
        incident.metadata["input"],
        "fixture",
        "Tool classification receives typed input after decode"
    )

    let report = try Expect.notNil(
        incident.report,
        "registered tool boundary attaches structured error evidence to the classified incident"
    )

    try Expect.equal(
        report.presentation.message,
        failure.message,
        "captured ErrorReport retains the underlying failure presentation"
    )

    let persisted = try JSONDecoder().decode(
        ToolCall.Failure.self,
        from: JSONEncoder().encode(
            failure
        )
    )
    let persistedIncident = try Expect.notNil(
        persisted.incident,
        "ToolCall.Failure Codable round trip retains the recovery incident"
    )

    try Expect.equal(
        persisted,
        failure,
        "ToolCall.Failure Codable round trip preserves structured recovery evidence"
    )
    _ = try Expect.notNil(
        persistedIncident.report,
        "ToolCall.Failure persistence retains the incident ErrorReport"
    )

    return true
}

private func capturedFailure(
    _ operation: () async throws -> Void
) async throws -> ToolCall.Failure {
    do {
        try await operation()
    } catch let error as ToolCall.Error {
        return error.failure
    }

    throw PhaseFailureFlowError.expectedToolCallFailure
}

private func phaseCall(
    id: String,
    name: String
) throws -> ToolCall {
    ToolCall(
        id: id,
        tool: ToolIdentifier(
            rawValue: name
        ),
        input: try JSONToolBridge.encode(
            PhaseFailureInput(
                value: "fixture"
            )
        )
    )
}

private struct PhaseFailureInput:
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

private struct PhaseFailureOutput:
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

private protocol PhaseFailureToolIdentity {
    static var identifier: ToolIdentifier { get }
}

private enum PhaseFailureDecodeIdentity:
    PhaseFailureToolIdentity
{
    static let identifier:
        ToolIdentifier = "phase_failure_decode"
}

private enum PhaseFailurePreflightIdentity:
    PhaseFailureToolIdentity
{
    static let identifier:
        ToolIdentifier = "phase_failure_preflight"
}

private enum PhaseFailureCallIdentity:
    PhaseFailureToolIdentity
{
    static let identifier:
        ToolIdentifier = "phase_failure_call"
}

private enum PhaseFailureProcessIdentity:
    PhaseFailureToolIdentity
{
    static let identifier:
        ToolIdentifier = "phase_failure_process"
}

private enum PhaseFailurePlanIdentity:
    PhaseFailureToolIdentity
{
    static let identifier:
        ToolIdentifier = "phase_failure_plan"
}

private struct PhaseFailureTool<
    Identity: PhaseFailureToolIdentity
>: Tool {
    typealias Input = PhaseFailureInput
    typealias Output = PhaseFailureOutput

    static var definition: ToolDefinition {
        .init(
            identifier: Identity.identifier,
            purpose:
                "Exercises one phase-aware Tool failure.",
            risk: .observe
        )
    }

    let failurePhase: ToolCall.Phase

    func preflight(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> ToolPreflight {
        if failurePhase == .preflight {
            throw PhaseFailureProbeError.preflight
        }

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: Self.definition.risk,
            summary: "fixture:\(input.value)"
        )
    }

    func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        if failurePhase == .call {
            throw PhaseFailureProbeError.call
        }

        return .init(
            value: input.value
        )
    }

    func process(
        _ output: Output,
        input _: Input
    ) throws -> ToolCall.ResultProjection? {
        if failurePhase == .process {
            throw PhaseFailureProbeError.process
        }

        return .init(
            status: "passed",
            summary: output.value
        )
    }
}

private struct RecoveryFailureTool: Tool {
    typealias Input = PhaseFailureInput
    typealias Output = PhaseFailureOutput

    static let definition = ToolDefinition(
        identifier: "recovery_failure_evidence",
        purpose:
            "Exercises structured recovery evidence for a typed tool failure.",
        risk: .observe
    )

    func preflight(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> ToolPreflight {
        ToolPreflight(
            tool: Self.definition.identifier,
            risk: Self.definition.risk,
            summary: "recovery-evidence:\(input.value)"
        )
    }

    func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        _ = input
        throw PhaseFailureProbeError.call
    }

    func classify(
        _ error: any Error,
        phase: ToolCall.Phase,
        input: Input?
    ) -> Recovery.Incident? {
        guard
            phase == .call,
            error is PhaseFailureProbeError,
            input?.value == "fixture"
        else {
            return nil
        }

        return Recovery.Incident(
            kind: .transport_transient,
            stage: .execution,
            effectState: .none,
            retrySafety: .safe,
            scope: .init(
                kind: .tool,
                identifier:
                    Self.definition.identifier.rawValue
            ),
            message: "fixture classified tool failure",
            metadata: [
                "input": input?.value ?? "missing",
            ]
        )
    }
}

private struct EncodeFailureOutput:
    Codable,
    Sendable,
    JSONSchemaProviding
{
    init() {}

    init(
        from decoder: any Decoder
    ) throws {
        _ = decoder
    }

    func encode(
        to encoder: any Encoder
    ) throws {
        _ = encoder
        throw PhaseFailureProbeError.encode
    }

    static var jsonschema: JSONSchema {
        .any
    }
}

private struct EncodeFailureTool: Tool {
    typealias Input = PhaseFailureInput
    typealias Output = EncodeFailureOutput

    static let definition = ToolDefinition(
        identifier: "phase_failure_encode",
        purpose: "Exercises output encoding failure.",
        risk: .observe
    )

    func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        _ = input
        return .init()
    }
}

private struct ReportedFailureTool: Tool {
    typealias Input = PhaseFailureInput
    typealias Output = PhaseFailureOutput

    static let definition = ToolDefinition(
        identifier: "typed_reported_failure",
        purpose:
            "Exercises typed model-visible reported failure.",
        risk: .observe
    )

    func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        _ = input

        throw AgentToolReportedFailure(
            output: Output(
                value: "reported"
            )
        )
    }

    func process(
        _ output: Output,
        input _: Input
    ) -> ToolCall.ResultProjection? {
        .init(
            status: "failed",
            summary: output.value
        )
    }
}

private enum PhaseFailureProbeError:
    Error,
    LocalizedError
{
    case preflight
    case call
    case process
    case encode

    var errorDescription: String? {
        switch self {
        case .preflight:
            "fixture preflight failure"

        case .call:
            "fixture call failure"

        case .process:
            "fixture process failure"

        case .encode:
            "fixture encode failure"
        }
    }
}

private enum PhaseFailureFlowError: Error {
    case expectedToolCallFailure
}
