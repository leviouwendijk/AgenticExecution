import Agentic
import AgenticExecution
import TestFlows
import Workspace

extension AgenticExecutionFlowTesting {
    static func runToolRegistryIntrinsics()
        async throws
        -> [TestDiagnostic]
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
            AgentToolRegistration.tool(
                ToolRegistryIntrinsicProbeTool<
                    ReadFileIntrinsicIdentity
                >(),
                execution: .fixed
            )
            AgentToolRegistration.tool(
                ToolRegistryIntrinsicProbeTool<
                    GitPushIntrinsicIdentity
                >(),
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
                ToolIdentifier(
                    "git_push"
                ),
                ToolIdentifier(
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
            AgentToolRegistration.tool(
                ToolRegistryIntrinsicProbeTool<
                    ReadFileIntrinsicIdentity
                >(),
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
            ToolCall(
                id: "inspect-tool-registry-intrinsic-test",
                tool: InspectToolRegistryTool
                    .identifier,
                input: try JSONToolBridge.encode(
                    input
                )
            ),
            workspace: nil
        )

        return try JSONToolBridge.decode(
            InspectToolRegistryToolOutput.self,
            from: result.result.output
        )
    }
}

private protocol ToolRegistryIntrinsicIdentity {
    static var definition: ToolDefinition { get }
}

private enum ReadFileIntrinsicIdentity:
    ToolRegistryIntrinsicIdentity
{
    static let definition = ToolDefinition(
        identifier: "read_file",
        purpose:
            "Read a bounded source file from the current workspace.",
        risk: .observe
    )
}

private enum GitPushIntrinsicIdentity:
    ToolRegistryIntrinsicIdentity
{
    static let definition = ToolDefinition(
        identifier: "git_push",
        purpose:
            "Push committed Git history to a configured remote repository.",
        risk: .privileged
    )
}

private struct ToolRegistryIntrinsicProbeTool<
    Identity: ToolRegistryIntrinsicIdentity
>: Tool {
    typealias Input =
        InspectToolRegistryToolInput
    typealias Output =
        InspectToolRegistryToolInput

    static var definition: ToolDefinition {
        Identity.definition
    }

    func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        input
    }
}
