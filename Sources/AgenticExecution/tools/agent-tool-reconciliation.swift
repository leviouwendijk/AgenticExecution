import AgenticRecovery

public enum AgentToolReconciliation<Output>: Sendable
where
    Output:
        Encodable &
        Sendable
{
    case applied(Output)
    case applied_without_output
    case not_applied
    case unknown

    public var state: Recovery.State {
        switch self {
        case .applied,
             .applied_without_output:
            .init(
                reconciled: .applied
            )

        case .not_applied:
            .init(
                reconciled: .not_applied
            )

        case .unknown:
            .init(
                reconciled: .unknown
            )
        }
    }
}
