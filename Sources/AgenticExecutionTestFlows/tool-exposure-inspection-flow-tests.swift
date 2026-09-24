import Agentic
import AgenticExecution
import TestFlows
import Workspace

extension AgenticExecutionFlowTesting {
    static func runToolExposureInspection()
        async throws
        -> [TestDiagnostic]
    {
        var registry = ToolRegistry()

        try registry.register {
            ExposureInspectionProbeTool<
                ExposureAlphaIdentity
            >()
            ExposureInspectionProbeTool<
                ExposureBetaIdentity
            >()
            ExposureInspectionProbeTool<
                ExposureGammaIdentity
            >()
        }

        let exposure = AgentToolExposure(
            policy: .discoverable(
                [
                    "alpha",
                    "missing",
                ]
            )
        )

        _ = try await exposure.activate(
            [
                "beta",
            ],
            in: registry
        )

        let inspection = await exposure.inspect(
            in: registry.inspect()
        )

        try Expect.equal(
            inspection.exposedIdentifiers
                .map(\.rawValue)
                .joined(separator: ","),
            "alpha,beta",
            "inspection reports seeded and activated exposure"
        )
        try Expect.equal(
            inspection.seededIdentifiers
                .map(\.rawValue)
                .joined(separator: ","),
            "alpha",
            "inspection ignores stale configured identifiers"
        )
        try Expect.equal(
            inspection.activatedIdentifiers
                .map(\.rawValue)
                .joined(separator: ","),
            "beta",
            "inspection distinguishes dynamic activation"
        )
        try Expect.equal(
            inspection.hiddenIdentifiers
                .map(\.rawValue)
                .joined(separator: ","),
            "gamma",
            "inspection reports deterministic hidden identifiers"
        )

        let source =
            AgentToolExposureInspectionSource(
                exposure: exposure
            )

        try registry.register(
            InspectToolExposureTool(
                source: source
            )
        )

        await source.bind(
            registryInspection: registry.inspect()
        )

        let result = try await registry.execute(
            ToolCall(
                id: "inspect-tool-exposure-flow",
                tool:
                    InspectToolExposureTool
                        .identifier,
                input: try JSONToolBridge.encode(
                    InspectToolExposureToolInput()
                )
            ),
            workspace: nil
        )

        let output = try JSONToolBridge.decode(
            InspectToolExposureToolOutput.self,
            from: result.result.output
        )

        try Expect.equal(
            output.registeredModelFacingCount,
            4,
            "tool uses the completed bound registry inspection"
        )
        try Expect.equal(
            output.hiddenCount,
            2,
            "tool reports current hidden count"
        )
        try Expect.equal(
            output.hiddenIdentifiers == nil,
            true,
            "tool omits hidden identifiers by default"
        )

        return [
            .message(
                "Tool exposure inspection uses live exposure state plus immutable completed-registry metadata."
            ),
        ]
    }
}

private protocol ExposureInspectionProbeIdentity {
    static var identifier: ToolIdentifier { get }
}

private enum ExposureAlphaIdentity:
    ExposureInspectionProbeIdentity
{
    static let identifier:
        ToolIdentifier = "alpha"
}

private enum ExposureBetaIdentity:
    ExposureInspectionProbeIdentity
{
    static let identifier:
        ToolIdentifier = "beta"
}

private enum ExposureGammaIdentity:
    ExposureInspectionProbeIdentity
{
    static let identifier:
        ToolIdentifier = "gamma"
}

private struct ExposureInspectionProbeTool<
    Identity: ExposureInspectionProbeIdentity
>: Tool {
    typealias Input =
        InspectToolExposureToolInput
    typealias Output =
        InspectToolExposureToolInput

    static var definition: ToolDefinition {
        .init(
            identifier: Identity.identifier,
            purpose: "Exposure inspection probe.",
            risk: .observe
        )
    }

    func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        input
    }
}
