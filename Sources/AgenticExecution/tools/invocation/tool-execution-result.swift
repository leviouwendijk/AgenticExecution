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
    public var observations: [ToolResultObservation]
    public var failure: ToolCall.Failure?
    public var recovery: Recovery.Record?

    public init(
        result: ToolResult,
        observations: [ToolResultObservation] = [],
        failure: ToolCall.Failure? = nil,
        recovery: Recovery.Record? = nil
    ) {
        self.result = result
        self.observations = observations
        self.failure = failure
        self.recovery = recovery
    }

    private enum CodingKeys: String, CodingKey {
        case result, observations, failure, recovery
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            result: try values.decode(ToolResult.self, forKey: .result),
            observations: try values.decodeIfPresent([ToolResultObservation].self, forKey: .observations) ?? [],
            failure: try values.decodeIfPresent(ToolCall.Failure.self, forKey: .failure),
            recovery: try values.decodeIfPresent(Recovery.Record.self, forKey: .recovery)
        )
    }
}
