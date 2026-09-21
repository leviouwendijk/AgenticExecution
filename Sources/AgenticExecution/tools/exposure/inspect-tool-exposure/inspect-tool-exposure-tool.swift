import Agentic
import Workspace

/// Inspect the live model-visible tool surface for one executor.
public struct InspectToolExposureTool:
    Tool
{
    public typealias Input =
        InspectToolExposureToolInput
    public typealias Output =
        InspectToolExposureToolOutput

    public static let identifier:
        ToolIdentifier = "inspect_tool_exposure"

    public static let description =
        "Inspect the current model-visible Agentic tool exposure. Reports policy, registered/exposed/hidden counts, seeded identifiers, and dynamically activated identifiers without changing exposure. Hidden identifiers are omitted by default."

    public static let risk:
        ActionRisk = .observe

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public let source:
        AgentToolExposureInspectionSource

    public init(
        source: AgentToolExposureInspectionSource
    ) {
        self.source = source
    }

    public func preflight(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = input

        return .init(
            tool: Self.definition.identifier,
            risk: Self.definition.risk,
            summary:
                "Inspect current model-visible tool exposure.",
            sideEffects: []
        )
    }

    public func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        .init(
            inspection: try await source.inspect(),
            includeHiddenIdentifiers:
                input.resolvedIncludeHiddenIdentifiers
        )
    }
}
