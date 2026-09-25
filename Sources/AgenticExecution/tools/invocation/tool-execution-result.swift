import Agentic

/// Canonical mechanical result of one tool execution operation.
///
/// `result` preserves the operation-facing tool contract. `failure` preserves
/// the exact durable tool-call failure when the terminal error result was produced
/// from one. `recovery` preserves mechanical recovery and reconciliation evidence
/// accumulated while executing the operation.
public struct ToolExecutionResult:
    Sendable,
    Codable,
    Hashable
{
    public var result: ToolResult
    public var failure: ToolCall.Failure?
    public var recovery: Recovery.Record?

    public init(
        result: ToolResult,
        failure: ToolCall.Failure? = nil,
        recovery: Recovery.Record? = nil
    ) {
        self.result = result
        self.failure = failure
        self.recovery = recovery
    }
}
