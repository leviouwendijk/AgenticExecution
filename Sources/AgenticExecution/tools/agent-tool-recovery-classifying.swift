import Agentic
import AgenticRecovery

/// Optional tool-local normalization of execution errors into generic recovery incidents.
///
/// Classification describes failure semantics only. AgenticExecution does not decide
/// whether recovery is authorized or perform retries; Runtime consumers own that policy.
public protocol AgentToolRecoveryClassifying: Sendable {
    func incident(
        for error: any Error,
        phase: AgentToolCallPhase,
        call: AgentToolCall
    ) -> Recovery.Incident?
}
