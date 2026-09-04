import Agentic
import AgenticExecution
import TestFlows

extension AgenticExecutionFlowTesting {
    static func runToolRegistryIntrinsics()
        async throws
        -> [TestFlowDiagnostic]
    {
        let bare = ToolRegistry()

        try Expect.equal(
            bare.count,
            0,
            "bare ToolRegistry remains empty"
        )
        try Expect.equal(
            bare.registeredTool(
                named: InspectToolRegistryTool.identifier.rawValue
            ) == nil,
            true,
            "bare ToolRegistry does not install intrinsic tools"
        )

        let registry = try Agentic.tool.registry {
            ToolRegistryIntrinsicProbeTool(
                identifier: "read_file",
                description:
                    "Read a bounded source file from the current workspace.",
                risk: .observe,
                execution: .fixed
            )
            ToolRegistryIntrinsicProbeTool(
                identifier: "git_push",
                description:
                    "Push committed Git history to a configured remote repository.",
                risk: .privileged,
                execution: .targetable
            )
        }

        try Expect.equal(
            registry.count,
            3,
            "canonical registry includes two declared tools plus one intrinsic tool"
        )
        _ = try Expect.notNil(
            registry.registeredTool(
                named: InspectToolRegistryTool.identifier.rawValue
            ),
            "canonical registry automatically installs inspect_tool_registry"
        )

        let listed = try await inspect(
            registry,
            input: .init()
        )

        try Expect.equal(
            listed.totalCount,
            2,
            "intrinsic inspection snapshot counts declared tools before intrinsic installation"
        )
        try Expect.equal(
            listed.returnedCount,
            2,
            "intrinsic inspection lists every declared tool"
        )
        try Expect.equal(
            listed.tools.map(
                \.identifier
            ),
            [
                AgentToolIdentifier(
                    "git_push"
                ),
                AgentToolIdentifier(
                    "read_file"
                ),
            ],
            "intrinsic inspection captures the completed declared registry in deterministic order"
        )
        try Expect.equal(
            listed.tools.contains {
                $0.identifier
                    == InspectToolRegistryTool.identifier
            },
            false,
            "intrinsic inspection does not recursively include itself"
        )

        let exact = try await inspect(
            registry,
            input: .init(
                identifier: "git_push",
                includeSchemas: true
            )
        )

        try Expect.equal(
            exact.returnedCount,
            1,
            "intrinsic inspection supports exact identifier lookup"
        )
        try Expect.equal(
            exact.tools.first?.workingLocation,
            Optional(
                AgentToolExecutionContract
                    .WorkingLocation
                    .targetable
            ),
            "intrinsic inspection retains execution metadata"
        )
        try Expect.equal(
            exact.tools.first?.semanticInputSchema != nil,
            true,
            "intrinsic inspection optionally returns the semantic input schema"
        )

        let optedOut = try Agentic.tool.registry(
            configuration: .init(
                includeIntrinsicTools: false
            )
        ) {
            ToolRegistryIntrinsicProbeTool(
                identifier: "read_file",
                description:
                    "Read a bounded source file from the current workspace.",
                risk: .observe,
                execution: .fixed
            )
        }

        try Expect.equal(
            optedOut.count,
            1,
            "registry configuration can hard-opt out of intrinsic tools"
        )
        try Expect.equal(
            optedOut.registeredTool(
                named: InspectToolRegistryTool.identifier.rawValue
            ) == nil,
            true,
            "intrinsic hard opt-out leaves only declared tools"
        )

        let setRegistry = try Agentic.tool.registry(
            toolSets: [
                ToolRegistryIntrinsicProbeSet(),
            ]
        )

        try Expect.equal(
            setRegistry.count,
            2,
            "tool-set bootstrap path also installs intrinsic tools"
        )
        _ = try Expect.notNil(
            setRegistry.registeredTool(
                named: InspectToolRegistryTool.identifier.rawValue
            ),
            "tool-set bootstrap path converges on canonical registry completion"
        )

        return [
            .message(
                "ToolRegistry stays bare at low level; Agentic.tool.registry installs inspect_tool_registry after declarations by default, captures only the completed declared registry, and honors the bootstrap hard opt-out."
            ),
        ]
    }
}

private extension AgenticExecutionFlowTesting {
    static func inspect(
        _ registry: ToolRegistry,
        input: InspectToolRegistryToolInput
    ) async throws -> InspectToolRegistryToolOutput {
        let result = try await registry.execute(
            AgentToolCall(
                id: "inspect-tool-registry-intrinsic-test",
                name: InspectToolRegistryTool
                    .identifier
                    .rawValue,
                input: try JSONToolBridge.encode(
                    input
                )
            ),
            context: .init()
        )

        return try JSONToolBridge.decode(
            InspectToolRegistryToolOutput.self,
            from: result.output
        )
    }
}

private struct ToolRegistryIntrinsicProbeSet:
    AgentToolSet
{
    func register(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register {
            ToolRegistryIntrinsicProbeTool(
                identifier: "set_probe",
                description:
                    "Probe tool registered through an AgentToolSet.",
                risk: .observe,
                execution: .fixed
            )
        }
    }
}

private struct ToolRegistryIntrinsicProbeTool:
    AgentTool
{
    typealias Input =
        InspectToolRegistryToolInput
    typealias Output =
        InspectToolRegistryToolInput

    let identifier: AgentToolIdentifier
    let description: String
    let risk: ActionRisk
    let execution: AgentToolExecutionContract

    func call(
        _ input: Input,
        context _: AgentToolExecutionContext
    ) async throws -> Output {
        input
    }
}
