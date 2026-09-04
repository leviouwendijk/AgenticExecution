import Agentic
import Foundation

/// Stable execution phase for one registered AgentTool call.
///
/// These phases describe the typed erasure boundary owned by AgenticExecution.
/// Unknown-tool resolution and approval policy happen outside this envelope.
public enum AgentToolCallPhase:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case decode
    case preflight
    case call
    case process
    case encode
}

/// Durable, presentation-neutral description of one failed AgentTool phase.
///
/// The arbitrary underlying Swift Error is intentionally not persisted. Runtime,
/// ToolPlan history, and later presentation layers retain this stable value.
public struct AgentToolCallFailure:
    Sendable,
    Codable,
    Hashable
{
    public let tool: AgentToolIdentifier
    public let toolCallID: String
    public let phase: AgentToolCallPhase
    public let message: String
    public let errorType: String

    public init(
        tool: AgentToolIdentifier,
        toolCallID: String,
        phase: AgentToolCallPhase,
        message: String,
        errorType: String
    ) {
        self.tool = tool
        self.toolCallID = toolCallID
        self.phase = phase
        self.message = message
        self.errorType = errorType
    }
}

/// Throwable carrier for a durable AgentToolCallFailure.
public struct AgentToolCallError:
    Error,
    Sendable,
    LocalizedError
{
    public let failure: AgentToolCallFailure

    public init(
        failure: AgentToolCallFailure
    ) {
        self.failure = failure
    }

    public init(
        tool: AgentToolIdentifier,
        toolCallID: String,
        phase: AgentToolCallPhase,
        underlying error: any Error
    ) {
        self.init(
            failure: .init(
                tool: tool,
                toolCallID: toolCallID,
                phase: phase,
                message: Self.message(
                    for: error
                ),
                errorType: String(
                    reflecting: type(
                        of: error
                    )
                )
            )
        )
    }

    public var errorDescription: String? {
        "Tool '\(failure.tool.rawValue)' failed during \(failure.phase.rawValue) for call '\(failure.toolCallID)': \(failure.message)"
    }
}

private extension AgentToolCallError {
    static func message(
        for error: any Error
    ) -> String {
        if let localized = error as? any LocalizedError,
           let description = localized.errorDescription
        {
            return description
        }

        return String(
            describing: error
        )
    }
}
