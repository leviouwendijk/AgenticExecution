public struct AgentToolReportedFailure<Output>:
    Error,
    Sendable
where
    Output:
        Encodable &
        Sendable
{
    public let output: Output

    public init(
        output: Output
    ) {
        self.output = output
    }
}
