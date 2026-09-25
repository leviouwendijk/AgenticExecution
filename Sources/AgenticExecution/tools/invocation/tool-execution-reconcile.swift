import Agentic

extension ToolExecution {
    func reconcile(
        _ call: ToolCall,
        decision: Recovery.Decision,
        attemptNumber: UInt,
        recovery: inout RecoveryState
    ) async throws -> ActionOutcome {
        do {
            guard let reconciliation = try await registry.reconcile(
                call,
                failure: recovery.failure,
                workspace: workspace
            ) else {
                let recoveryError =
                    Error.reconciliation_unsupported

                recovery.attempts.append(
                    Recovery.Attempt(
                        capturing: recoveryError,
                        number: attemptNumber,
                        action: decision.action,
                        state: recovery.state
                    )
                )

                return .complete(
                    ToolExecutionResult(
                        result: try makeErrorResult(
                            for: call,
                            error: recoveryError
                        ),
                        recovery: recovery.record(
                            outcome: .failed
                        )
                    )
                )
            }

            let state = reconciliation.state

            recovery.attempts.append(
                Recovery.Attempt(
                    number: attemptNumber,
                    action: decision.action,
                    status: .succeeded,
                    state: state
                )
            )
            recovery.state = state

            switch reconciliation {
            case .applied(var result):
                result.recovery = recovery.record(
                    outcome: .recovered
                )
                return .complete(
                    result
                )

            case .applied_without_output:
                let recoveryError =
                    Error.applied_without_output

                return .complete(
                    ToolExecutionResult(
                        result: try makeErrorResult(
                            for: call,
                            error: recoveryError
                        ),
                        recovery: recovery.record(
                            outcome: .failed
                        )
                    )
                )

            case .not_applied:
                recovery.advance(
                    to: state
                )
                return .continueRecovery

            case .unknown:
                guard decision.limit.nextAttempt(
                    after: recovery.completedAttemptsInStep
                ) == nil else {
                    return .continueRecovery
                }

                let recoveryError =
                    Error.reconciliation_unresolved

                return .complete(
                    ToolExecutionResult(
                        result: try makeErrorResult(
                            for: call,
                            error: recoveryError
                        ),
                        recovery: recovery.record(
                            outcome: .exhausted
                        )
                    )
                )
            }
        } catch {
            recovery.attempts.append(
                Recovery.Attempt(
                    capturing: error,
                    number: attemptNumber,
                    action: decision.action,
                    state: recovery.state
                )
            )

            guard decision.limit.nextAttempt(
                after: recovery.completedAttemptsInStep
            ) == nil else {
                return .continueRecovery
            }

            return .complete(
                ToolExecutionResult(
                    result: try makeErrorResult(
                        for: call,
                        error: error
                    ),
                    recovery: recovery.record(
                        outcome: .exhausted
                    )
                )
            )
        }
    }
}
