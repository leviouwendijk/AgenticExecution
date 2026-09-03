import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Primitives
import Schema
import TestFlows

extension AgenticExecutionFlowTesting {
    static func runTypedAgentToolContract() async throws -> [TestFlowDiagnostic] {
        let probe = TypedAgentToolContractProbe()
        let liveObservations = TypedAgentToolObservationStore()
        let tool = TypedAgentToolContractTool(
            probe: probe
        )
        var registry = ToolRegistry()

        try registry.register(
            tool
        )

        let call = AgentToolCall(
            id: "typed-tool-contract-call",
            name: tool.identifier.rawValue,
            input: try JSONToolBridge.encode(
                TypedAgentToolContractInput(
                    value: "hello"
                )
            )
        )

        let parsed = try registry.parseModelCall(
            call
        )

        try Expect.equal(
            parsed.capability.definition.name,
            "typed_tool_contract",
            "registration preserves the concrete tool definition"
        )
        try Expect.equal(
            parsed.capability.execution.workingLocation,
            .targetable,
            "registration captures working-location capability before type erasure"
        )

        let preflight = try await registry.preflight(
            call,
            context: .init()
        )

        try Expect.contains(
            preflight.summary,
            "hello",
            "typed preflight receives decoded Input"
        )

        let result = try await registry.execute(
            call,
            context: .init(
                observationSink: .init { observation in
                    await liveObservations.append(
                        observation
                    )
                }
            )
        )
        let output = try JSONToolBridge.decode(
            TypedAgentToolContractOutput.self,
            from: result.output
        )
        let processing = try Expect.notNil(
            result.processing,
            "registered execution reconstructs processing"
        )
        let projection = try Expect.notNil(
            processing.projection,
            "typed process supplies the result projection"
        )

        try Expect.equal(
            output.value,
            "HELLO",
            "typed call returns typed Output through JSON erasure"
        )
        try Expect.equal(
            projection.summary,
            Optional("input:hello output:HELLO"),
            "process sees both typed Input and typed Output"
        )
        try Expect.equal(
            processing.observations.map(\.content),
            [
                "starting:hello",
                "finished:HELLO",
            ],
            "temporal observations are retained in the final result"
        )
        try Expect.equal(
            await liveObservations.contents(),
            [
                "starting:hello",
                "finished:HELLO",
            ],
            "the same observations are forwarded live while execution runs"
        )
        try Expect.equal(
            await probe.preflightValues(),
            [
                "hello",
            ],
            "typed preflight crosses the erasure boundary once"
        )
        try Expect.equal(
            await probe.callValues(),
            [
                "hello",
            ],
            "stateful tool dependencies survive registration erasure"
        )

        try proveWorkspaceSelectionAuthority()

        return [
            .field(
                "output",
                output.value
            ),
            .field(
                "observations",
                "\(processing.observations.count)"
            ),
            .field(
                "projection",
                projection.status
            ),
        ]
    }
}

private func proveWorkspaceSelectionAuthority() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "agentic-workspace-selection-\(UUID().uuidString)",
            isDirectory: true
        )

    defer {
        try? FileManager.default.removeItem(
            at: root
        )
    }

    try FileManager.default.createDirectory(
        at: root.appendingPathComponent(
            "Allowed/Private",
            isDirectory: true
        ),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: root.appendingPathComponent(
            "Denied",
            isDirectory: true
        ),
        withIntermediateDirectories: true
    )

    let workspace = try AgentWorkspace(
        root: root,
        selection: try WorkspaceSelection(
            exactPaths: [
                "Allowed",
            ],
            includeExpressions: [
                "Allowed/**",
            ],
            excludeExpressions: [
                "Allowed/Private",
                "Allowed/Private/**",
            ]
        )
    )

    _ = try workspace.location(
        for: .init(
            subpath: "Allowed"
        )
    )

    var outsideIncludesDenied = false
    do {
        _ = try workspace.location(
            for: .init(
                subpath: "Denied"
            )
        )
    } catch let error as WorkspaceAccessError {
        if case .selectionDenied = error {
            outsideIncludesDenied = true
        } else {
            throw error
        }
    }

    try Expect.true(
        outsideIncludesDenied,
        "workspace selection denies paths outside includes"
    )

    var exclusionDenied = false
    do {
        _ = try workspace.location(
            for: .init(
                subpath: "Allowed/Private"
            )
        )
    } catch let error as WorkspaceAccessError {
        if case .selectionDenied = error {
            exclusionDenied = true
        } else {
            throw error
        }
    }

    try Expect.true(
        exclusionDenied,
        "workspace selection exclusions override includes"
    )

    var absoluteRejected = false
    do {
        _ = try WorkspaceSelection(
            includeExpressions: [
                "/tmp/**",
            ]
        )
    } catch let error as WorkspaceSelectionError {
        if case .nonRelativeExpression = error {
            absoluteRejected = true
        } else {
            throw error
        }
    }

    try Expect.true(
        absoluteRejected,
        "workspace selection accepts only root-relative expressions"
    )
}

private struct TypedAgentToolContractInput:
    Sendable,
    Codable,
    Hashable,
    JSONSchemaProviding
{
    let value: String

    static var jsonschema: JSONSchema {
        JSONSchema.object {
            JSONSchema.string(
                "value",
                required: true
            )
        }
    }
}

private struct TypedAgentToolContractOutput:
    Sendable,
    Codable,
    Hashable
{
    let value: String
}

private actor TypedAgentToolContractProbe {
    private var preflights: [String] = []
    private var calls: [String] = []

    func recordPreflight(
        _ value: String
    ) {
        preflights.append(
            value
        )
    }

    func recordCall(
        _ value: String
    ) {
        calls.append(
            value
        )
    }

    func preflightValues() -> [String] {
        preflights
    }

    func callValues() -> [String] {
        calls
    }
}

private actor TypedAgentToolObservationStore {
    private var observations:
        [AgentToolResultObservation] = []

    func append(
        _ observation: AgentToolResultObservation
    ) {
        observations.append(
            observation
        )
    }

    func contents() -> [String] {
        observations.map(\.content)
    }
}

private struct TypedAgentToolContractTool:
    AgentTool
{
    typealias Input = TypedAgentToolContractInput
    typealias Output = TypedAgentToolContractOutput

    let identifier: AgentToolIdentifier =
        "typed_tool_contract"
    let description =
        "Exercise typed AgentTool registration and execution."
    let risk: ActionRisk = .observe
    let execution: AgentToolExecutionContract = .targetable
    let probe: TypedAgentToolContractProbe

    func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        await probe.recordPreflight(
            input.value
        )

        return ToolPreflight(
            toolName: name,
            risk: risk,
            workspaceRoot: context.workspace?.rootURL.path,
            summary:
                "Typed preflight for \(input.value).",
            sideEffects: []
        )
    }

    func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        await probe.recordCall(
            input.value
        )
        await context.observe(
            .init(
                kind: .detail,
                label: "phase",
                content: "starting:\(input.value)"
            )
        )

        let output = Output(
            value: input.value.uppercased()
        )

        await context.observe(
            .init(
                kind: .detail,
                label: "phase",
                content: "finished:\(output.value)"
            )
        )

        return output
    }

    func process(
        _ output: Output,
        input: Input,
        context _: AgentToolExecutionContext
    ) -> AgentToolResultProjection? {
        .init(
            status: "completed",
            summary:
                "input:\(input.value) output:\(output.value)",
            facts: [
                .init(
                    label: "input",
                    value: input.value
                ),
                .init(
                    label: "output",
                    value: output.value
                ),
            ]
        )
    }
}
