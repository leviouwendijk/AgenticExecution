import Agentic
import AgenticExecution
import AgenticRecovery
import Foundation
import Primitives
import Schema
import TestFlows

extension AgenticExecutionFlowTesting {
    static func runToolCallFailureEnvelope() async throws -> [TestFlowDiagnostic] {
        try await provePhase(
            .decode,
            tool: PhaseFailureTool(
                identifier: "phase_failure_decode",
                failurePhase: .call
            ),
            call: AgentToolCall(
                id: "phase-failure-decode-call",
                name: "phase_failure_decode",
                input: .object([:])
            ),
            operation: .execute
        )

        try await provePhase(
            .preflight,
            tool: PhaseFailureTool(
                identifier: "phase_failure_preflight",
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
            tool: PhaseFailureTool(
                identifier: "phase_failure_call",
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
            tool: PhaseFailureTool(
                identifier: "phase_failure_process",
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
                AgentToolCallPhase.allCases
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

private func provePhase(
    _ expectedPhase: AgentToolCallPhase,
    tool: PhaseFailureTool,
    call: AgentToolCall,
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
                context: .init()
            )

        case .execute:
            _ = try await registry.execute(
                call,
                context: .init()
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
            context: .init()
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
        context: .init()
    )
    let output = try JSONToolBridge.decode(
        PhaseFailureOutput.self,
        from: result.output
    )
    let processing = try Expect.notNil(
        result.processing,
        "reported failure retains result processing"
    )
    let projection = try Expect.notNil(
        processing.projection,
        "reported failure still runs typed process"
    )

    try Expect.true(
        result.isError,
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
    try Expect.equal(
        processing.observations.map(\.content),
        [
            "reported:reported",
        ],
        "reported failure retains temporal observations"
    )
}

private func proveToolPlanFailurePersistence() async throws {
    let tool = PhaseFailureTool(
        identifier: "phase_failure_plan",
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
    let plan = AgentToolPlan(
        id: "phase-failure-plan",
        root: .call(
            call
        )
    )
    let run = try await AgentToolPlanRunExecutor(
        invoker: invoker
    ).start(
        plan,
        executionPolicy: .single_step
    )
    let persisted = try JSONDecoder().decode(
        AgentToolPlanRun.self,
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
            context: .init()
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
        AgentToolCallFailure.self,
        from: JSONEncoder().encode(
            failure
        )
    )
    let persistedIncident = try Expect.notNil(
        persisted.incident,
        "AgentToolCallFailure Codable round trip retains the recovery incident"
    )

    try Expect.equal(
        persisted,
        failure,
        "AgentToolCallFailure Codable round trip preserves structured recovery evidence"
    )
    _ = try Expect.notNil(
        persistedIncident.report,
        "AgentToolCallFailure persistence retains the incident ErrorReport"
    )

    return true
}

private func capturedFailure(
    _ operation: () async throws -> Void
) async throws -> AgentToolCallFailure {
    do {
        try await operation()
    } catch let error as AgentToolCallError {
        return error.failure
    }

    throw PhaseFailureFlowError.expectedToolCallFailure
}

private func phaseCall(
    id: String,
    name: String
) throws -> AgentToolCall {
    AgentToolCall(
        id: id,
        name: name,
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
    Hashable
{
    let value: String
}

private struct PhaseFailureTool: AgentTool {
    typealias Input = PhaseFailureInput
    typealias Output = PhaseFailureOutput

    let identifier: AgentToolIdentifier
    let failurePhase: AgentToolCallPhase

    var description: String {
        "Exercises one phase-aware AgentTool failure."
    }

    var risk: ActionRisk {
        .observe
    }

    func preflight(
        _ input: Input,
        context _: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        if failurePhase == .preflight {
            throw PhaseFailureProbeError.preflight
        }

        return ToolPreflight(
            toolName: name,
            risk: risk,
            summary: "fixture:\(input.value)"
        )
    }

    func call(
        _ input: Input,
        context _: AgentToolExecutionContext
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
        input _: Input,
        context _: AgentToolExecutionContext
    ) throws -> AgentToolResultProjection? {
        if failurePhase == .process {
            throw PhaseFailureProbeError.process
        }

        return .init(
            status: "passed",
            summary: output.value
        )
    }
}

private struct RecoveryFailureTool:
    AgentTool,
    AgentToolRecoveryClassifying
{
    typealias Input = PhaseFailureInput
    typealias Output = PhaseFailureOutput

    let identifier: AgentToolIdentifier =
        "recovery_failure_evidence"

    var description: String {
        "Exercises structured recovery evidence for a typed tool failure."
    }

    var risk: ActionRisk {
        .observe
    }

    func preflight(
        _ input: Input,
        context _: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        ToolPreflight(
            toolName: name,
            risk: risk,
            summary: "recovery-evidence:\(input.value)"
        )
    }

    func call(
        _ input: Input,
        context _: AgentToolExecutionContext
    ) async throws -> Output {
        _ = input
        throw PhaseFailureProbeError.call
    }

    func incident(
        for error: any Error,
        phase: AgentToolCallPhase,
        call: AgentToolCall
    ) -> Recovery.Incident? {
        guard
            phase == .call,
            error is PhaseFailureProbeError
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
                identifier: identifier.rawValue
            ),
            message: "fixture classified tool failure",
            metadata: [
                "tool_call_id": call.id,
            ]
        )
    }
}

private struct EncodeFailureOutput:
    Encodable,
    Sendable
{
    func encode(
        to encoder: any Encoder
    ) throws {
        _ = encoder
        throw PhaseFailureProbeError.encode
    }
}

private struct EncodeFailureTool: AgentTool {
    typealias Input = PhaseFailureInput
    typealias Output = EncodeFailureOutput

    let identifier: AgentToolIdentifier =
        "phase_failure_encode"

    let description =
        "Exercises output encoding failure."

    let risk: ActionRisk =
        .observe

    func call(
        _ input: Input,
        context _: AgentToolExecutionContext
    ) async throws -> Output {
        _ = input
        return .init()
    }
}

private struct ReportedFailureTool: AgentTool {
    typealias Input = PhaseFailureInput
    typealias Output = PhaseFailureOutput

    let identifier: AgentToolIdentifier =
        "typed_reported_failure"

    let description =
        "Exercises typed model-visible reported failure."

    let risk: ActionRisk =
        .observe

    func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let output = Output(
            value: "reported"
        )

        await context.observe(
            .init(
                kind: .diagnostic,
                label: "reported",
                content: "reported:\(output.value)"
            )
        )

        _ = input

        throw AgentToolReportedFailure(
            output: output
        )
    }

    func process(
        _ output: Output,
        input _: Input,
        context _: AgentToolExecutionContext
    ) -> AgentToolResultProjection? {
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
