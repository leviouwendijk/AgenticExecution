import Agentic
import AgenticRecovery

/// Canonical mechanical result of one tool execution operation.
///
/// `result` preserves the operation-facing tool contract. `recovery` preserves
/// mechanical recovery and reconciliation evidence accumulated while executing
/// the operation.
public struct AgentToolExecutionResult: Sendable {
    public var result: AgentToolResult
    public var recovery: Recovery.Record?

    public init(
        result: AgentToolResult,
        recovery: Recovery.Record? = nil
    ) {
        self.result = result
        self.recovery = recovery
    }
}
