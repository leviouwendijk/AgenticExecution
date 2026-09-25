import Agentic
import Foundation
import Primitives

extension ToolExecution {
    enum Error:
        Swift.Error,
        LocalizedError
    {
        case reconciliation_unsupported
        case reconciliation_unresolved
        case applied_without_output
        case preflight_changed
        case recovery_exhausted
        case action_unsupported(Recovery.Action)

        var errorDescription: String? {
            switch self {
            case .reconciliation_unsupported:
                return "Tool does not support reconciliation for the classified failure."

            case .reconciliation_unresolved:
                return "Tool reconciliation could not determine whether the operation was applied."

            case .applied_without_output:
                return "Tool reconciliation confirmed the operation was applied but could not reconstruct the tool output."

            case .preflight_changed:
                return "Tool preflight changed after reconciliation; retry requires fresh approval."

            case .recovery_exhausted:
                return "Tool recovery exhausted its authored mechanical recovery plan."

            case .action_unsupported(let action):
                return "Tool execution does not mechanically execute recovery action '\(action.rawValue)'."
            }
        }
    }

    func makeErrorResult(
        for call: ToolCall,
        error: any Swift.Error
    ) throws -> ToolResult {
        let payload = Error.Payload(
            kind: "tool_error",
            toolCallID: call.id,
            toolName: call.tool.rawValue,
            message: localizedDescription(
                for: error
            )
        )

        return ToolResult(
            toolCallID: call.id,
            tool: call.tool,
            output: try JSONToolBridge.encode(
                payload
            ),
            isError: true
        )
    }

    func localizedDescription(
        for error: any Swift.Error
    ) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty
        {
            return description
        }

        return String(
            describing: error
        )
    }
}

extension ToolExecution.Error {
    struct Payload:
        Encodable,
        Sendable
    {
        let kind: String
        let toolCallID: String
        let toolName: String
        let message: String
    }
}
