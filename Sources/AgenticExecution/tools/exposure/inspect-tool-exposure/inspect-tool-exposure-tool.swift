import Agentic
import AgenticWorkspace

/// Inspect the live model-visible tool surface for one executor.
public struct InspectToolExposureTool:
    AgentTool
{
    public typealias Input =
        InspectToolExposureToolInput
    public typealias Output =
        InspectToolExposureToolOutput

    public static let identifier:
        AgentToolIdentifier = "inspect_tool_exposure"

    public static let description =
        "Inspect the current model-visible Agentic tool exposure. Reports policy, registered/exposed/hidden counts, seeded identifiers, and dynamically activated identifiers without changing exposure. Hidden identifiers are omitted by default."

    public static let risk:
        ActionRisk = .observe

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public let source:
        AgentToolExposureInspectionSource

    public init(
        source: AgentToolExposureInspectionSource
    ) {
        self.source = source
    }

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = input

        return ToolPreflight(
            toolName: name,
            risk: risk,
            workspaceRoot:
                context.workspace?.rootURL.path,
            summary:
                "Inspect current model-visible tool exposure.",
            sideEffects: []
        )
    }

    public func call(
        _ input: Input,
        context _: AgentToolExecutionContext
    ) async throws -> Output {
        .init(
            inspection: try await source.inspect(),
            includeHiddenIdentifiers:
                input.resolvedIncludeHiddenIdentifiers
        )
    }
}
