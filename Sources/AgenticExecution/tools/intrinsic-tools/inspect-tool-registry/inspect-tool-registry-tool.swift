import Agentic
import AgenticWorkspace
import Foundation
import Primitives
import Schema

/// Intrinsic model-facing projection of the declared tool registry captured at bootstrap.
public struct InspectToolRegistryTool:
    AgentTool
{
    public typealias Input =
        InspectToolRegistryToolInput
    public typealias Output =
        InspectToolRegistryToolOutput

    public static let identifier:
        AgentToolIdentifier = "inspect_tool_registry"

    public static let description =
        "Inspect the declared Agentic tool registry captured before intrinsic tools are installed. Lists registered capabilities or reads one exact identifier, with optional semantic input schemas. This does not report or change current model-visible tool exposure."

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

    public let inspection:
        AgentToolRegistryInspection

    public init(
        inspection: AgentToolRegistryInspection
    ) {
        self.inspection = inspection
    }

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let identifier = normalizedIdentifier(
            input.identifier
        )

        return ToolPreflight(
            toolName: name,
            risk: risk,
            workspaceRoot:
                context.workspace?.rootURL.path,
            summary:
                identifier.map {
                    "Inspect declared registered tool '\($0)' without changing model exposure."
                }
                ?? "Inspect all \(inspection.totalCount) captured declared tool(s) without changing model exposure.",
            sideEffects: []
        )
    }

    public func call(
        _ input: Input,
        context _: AgentToolExecutionContext
    ) async throws -> Output {
        let entries:
            [AgentToolRegistryInspectionEntry]

        if let identifier = normalizedIdentifier(
            input.identifier
        ) {
            entries = inspection.tools.filter { entry in
                entry.identifier.rawValue
                    == identifier
            }
        } else {
            entries = inspection.tools
        }

        let tools = entries.map { entry in
            InspectedAgentTool(
                identifier: entry.identifier,
                description: entry.description,
                risk: entry.risk,
                modelFacing: entry.isModelFacing,
                workingLocation:
                    entry.workingLocation,
                hasSemanticInputSchema:
                    entry.semanticInputSchema != nil,
                semanticInputSchema:
                    input.resolvedIncludeSchemas
                        ? entry.semanticInputSchema?.jsonvalue
                        : nil
            )
        }

        return .init(
            totalCount: inspection.totalCount,
            returnedCount: tools.count,
            tools: tools
        )
    }
}

private extension InspectToolRegistryTool {
    func normalizedIdentifier(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty
            ? nil
            : trimmed
    }
}
