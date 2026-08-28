import Primitives

public struct AgentToolReportedFailure:
    Error,
    Sendable
{
    public let output: JSONValue

    public init(
        output: JSONValue
    ) {
        self.output = output
    }
}
