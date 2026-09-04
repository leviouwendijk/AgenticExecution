import Agentic
import AgenticExecution
import TestFlows

extension AgenticExecutionFlowTesting {
    static func runToolExposureInspection()
        async throws
        -> [TestFlowDiagnostic]
    {
        var registry = ToolRegistry()

        try registry.register {
            ExposureInspectionProbeTool(
                identifier: "alpha"
            )
            ExposureInspectionProbeTool(
                identifier: "beta"
            )
            ExposureInspectionProbeTool(
                identifier: "gamma"
            )
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
            AgentToolCall(
                id: "inspect-tool-exposure-flow",
                name:
                    InspectToolExposureTool
                        .identifier
                        .rawValue,
                input: try JSONToolBridge.encode(
                    InspectToolExposureToolInput()
                )
            ),
            context: .init()
        )

        let output = try JSONToolBridge.decode(
            InspectToolExposureToolOutput.self,
            from: result.output
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

private struct ExposureInspectionProbeTool:
    AgentTool
{
    typealias Input =
        InspectToolExposureToolInput
    typealias Output =
        InspectToolExposureToolInput

    let identifier: AgentToolIdentifier
    let description: String
    let risk: ActionRisk = .observe

    init(
        identifier: AgentToolIdentifier
    ) {
        self.identifier = identifier
        self.description =
            "Exposure inspection probe."
    }

    func call(
        _ input: Input,
        context _: AgentToolExecutionContext
    ) async throws -> Output {
        input
    }
}
