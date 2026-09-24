import Agentic
import AgenticExecution
import Primitives
import Schema
import TestFlows
import Workspace

extension AgenticExecutionFlowTesting {
    static func runToolExposureAll() async throws -> [TestDiagnostic] {
        let registry = try toolExposureRegistry()
        let exposure = AgentToolExposure(
            policy: .all
        )

        let names = try await exposure
            .definitions(
                in: registry
            )
            .map(\.name)

        try Expect.equal(
            names,
            [
                "alpha_tool",
                "beta_tool",
            ],
            "all exposure advertises every model-facing tool and excludes host-only tools"
        )

        try Expect.equal(
            await exposure.isExposed(
                "alpha_tool",
                in: registry
            ),
            true,
            "all exposure exposes alpha_tool"
        )

        try Expect.equal(
            await exposure.isExposed(
                "beta_tool",
                in: registry
            ),
            true,
            "all exposure exposes beta_tool"
        )

        return [
            .field(
                "advertised",
                names.joined(separator: ",")
            ),
        ]
    }

    static func runToolExposureExplicit() async throws -> [TestDiagnostic] {
        let registry = try toolExposureRegistry()
        let exposure = AgentToolExposure(
            policy: .explicit(
                [
                    "alpha_tool",
                ]
            )
        )

        let names = try await exposure
            .definitions(
                in: registry
            )
            .map(\.name)

        try Expect.equal(
            names,
            [
                "alpha_tool",
            ],
            "explicit exposure advertises only the requested tool"
        )

        let betaCall = try toolExposureCall(
            id: "explicit-beta",
            name: "beta_tool"
        )

        do {
            _ = try await exposure.parseModelCall(
                betaCall,
                registry: registry
            )

            throw ToolExposureFlowFailure.expectedUnexposedToolRejection
        } catch AgentToolExposureError.toolNotExposed(let tool) {
            try Expect.equal(
                tool,
                "beta_tool",
                "explicit exposure rejects registered but unexposed model calls"
            )
        }

        do {
            _ = try await exposure.activate(
                [
                    "beta_tool",
                ],
                in: registry
            )

            throw ToolExposureFlowFailure.expectedExplicitActivationRejection
        } catch AgentToolExposureError.activationNotAllowed {
        }

        return [
            .field(
                "advertised",
                names.joined(separator: ",")
            ),
        ]
    }

    static func runToolExposureDiscoverable() async throws -> [TestDiagnostic] {
        let registry = try toolExposureRegistry()
        let exposure = AgentToolExposure(
            policy: .discoverable(
                [
                    "alpha_tool",
                ]
            )
        )

        let before = try await exposure
            .definitions(
                in: registry
            )
            .map(\.name)

        try Expect.equal(
            before,
            [
                "alpha_tool",
            ],
            "discoverable exposure begins with only its seed"
        )

        let activated = try await exposure.activate(
            [
                "beta_tool",
            ],
            in: registry
        )

        try Expect.equal(
            activated,
            [
                ToolIdentifier(
                    "beta_tool"
                ),
            ],
            "discoverable exposure reports newly activated tools"
        )

        let after = try await exposure
            .definitions(
                in: registry
            )
            .map(\.name)

        try Expect.equal(
            after,
            [
                "alpha_tool",
                "beta_tool",
            ],
            "discoverable activation persists in subsequent exposure reads"
        )

        let parsed = try await exposure.parseModelCall(
            try toolExposureCall(
                id: "discoverable-beta",
                name: "beta_tool"
            ),
            registry: registry
        )

        try Expect.equal(
            parsed.call.tool.rawValue,
            "beta_tool",
            "newly activated tool becomes model-callable"
        )

        return [
            .field(
                "before",
                before.joined(separator: ",")
            ),
            .field(
                "after",
                after.joined(separator: ",")
            ),
        ]
    }

    static func runToolExposureRegistryPreservation() async throws -> [TestDiagnostic] {
        let registry = try toolExposureRegistry()
        let exposure = AgentToolExposure(
            policy: .discoverable(
                []
            )
        )

        try Expect.equal(
            registry.count,
            3,
            "registry retains the complete installed tool universe"
        )

        try Expect.equal(
            registry.definitions.map(\.name),
            [
                "alpha_tool",
                "beta_tool",
                "host_probe",
            ],
            "canonical registry definitions retain model-facing and host-only tools"
        )

        try Expect.equal(
            registry.modelFacingDefinitions.map(\.name),
            [
                "alpha_tool",
                "beta_tool",
            ],
            "model-facing projection excludes host-only tools without removing them from registry"
        )

        try Expect.equal(
            try await exposure.definitions(
                in: registry
            ).count,
            0,
            "empty discoverable exposure may begin with no model-visible definitions"
        )

        _ = try await exposure.activate(
            [
                "alpha_tool",
            ],
            in: registry
        )

        try Expect.equal(
            registry.count,
            3,
            "activation never mutates ToolRegistry"
        )

        try Expect.equal(
            registry.registeredTool(
                named: "host_probe"
            ) != nil,
            true,
            "host-only tool remains installed after model exposure changes"
        )

        return [
            .field(
                "registry-count",
                "\(registry.count)"
            ),
            .field(
                "model-facing-count",
                "\(registry.modelFacingDefinitions.count)"
            ),
        ]
    }
}

private struct ToolExposureProbeInput:
    Sendable,
    Codable,
    JSONSchemaProviding
{
    static var jsonschema: JSONSchema {
        .object {}
    }
}

private protocol ToolExposureProbeIdentity {
    static var definition: ToolDefinition { get }
}

private enum AlphaExposureToolIdentity:
    ToolExposureProbeIdentity
{
    static let definition = ToolDefinition(
        identifier: "alpha_tool",
        purpose:
            "Alpha model-facing exposure fixture.",
        risk: .observe
    )
}

private enum BetaExposureToolIdentity:
    ToolExposureProbeIdentity
{
    static let definition = ToolDefinition(
        identifier: "beta_tool",
        purpose:
            "Beta model-facing exposure fixture.",
        risk: .observe
    )
}

private struct ToolExposureProbeTool<
    Identity: ToolExposureProbeIdentity
>: Tool {
    typealias Input = ToolExposureProbeInput
    typealias Output = ToolExposureProbeInput

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

private struct ToolExposureHostProbeTool: Tool {
    typealias Input = ToolExposureProbeInput
    typealias Output = ToolExposureProbeInput

    static let definition = ToolDefinition(
        identifier: "host_probe",
        purpose:
            "Trusted host-only exposure fixture.",
        risk: .observe
    )

    func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        input
    }
}

private enum ToolExposureFlowFailure: Error {
    case expectedUnexposedToolRejection
    case expectedExplicitActivationRejection
}

private func toolExposureRegistry() throws -> ToolRegistry {
    var registry = ToolRegistry()

    try registry.register(
        ToolExposureProbeTool<
            AlphaExposureToolIdentity
        >()
    )
    try registry.register(
        ToolExposureProbeTool<
            BetaExposureToolIdentity
        >()
    )

    try registry.register(
        ToolExposureHostProbeTool(),
        modelContract: .hostOnly
    )

    return registry
}

private func toolExposureCall(
    id: String,
    name: String
) throws -> ToolCall {
    ToolCall(
        id: id,
        tool: ToolIdentifier(
            rawValue: name
        ),
        input: try JSONToolBridge.encode(
            ToolExposureProbeInput()
        )
    )
}
