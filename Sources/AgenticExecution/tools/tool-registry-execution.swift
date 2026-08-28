import Agentic
import Foundation
import Primitives

public enum ToolRegistryExecutionError: Error, Sendable, LocalizedError {
    case missingTool(String)

    public var errorDescription: String? {
        switch self {
        case .missingTool(let name):
            return "No tool is registered with name '\(name)'."
        }
    }
}

public extension ToolRegistry {
    func execute(
        _ call: AgentToolCall,
        context: AgentToolExecutionContext
    ) async throws -> AgentToolResult {
        guard let tool = tool(
            named: call.name
        ) else {
            throw ToolRegistryExecutionError.missingTool(
                call.name
            )
        }

        let output: JSONValue
        let isError: Bool

        do {
            output = try await tool.call(
                input: call.input,
                context: context.withToolCallID(
                    call.id
                )
            )
            isError = false
        } catch let failure as AgentToolReportedFailure {
            output = failure.output
            isError = true
        }

        let processing = tool.processResult(
            input: call.input,
            output: output,
            workspace: context.workspace
        )

        return .init(
            toolCallID: call.id,
            name: call.name,
            output: output,
            processing:
                processing.isEmpty
                    ? nil
                    : processing,
            isError: isError
        )
    }
}
