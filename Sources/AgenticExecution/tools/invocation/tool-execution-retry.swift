import Agentic

extension ToolExecution {
    func retrySameOperation(
        _ call: ToolCall,
        preflight: ToolPreflight,
        decision: Recovery.Decision,
        attemptNumber: UInt,
        recovery: inout RecoveryState
    ) async throws -> ActionOutcome {
        if preflight.risk.isMutating {
            do {
                let refreshed = try await registry.preflight(
                    call,
                    workspace: workspace
                )

                guard refreshed == preflight else {
                    let recoveryError =
                        Error.preflight_changed

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
            } catch {
                recovery.attempts.append(
                    Recovery.Attempt(
                        capturing: error,
                        number: attemptNumber,
                        action: decision.action,
                        state: recovery.state
                    )
                )

                return .complete(
                    ToolExecutionResult(
                        result: try makeErrorResult(
                            for: call,
                            error: error
                        ),
                        recovery: recovery.record(
                            outcome: .failed
                        )
                    )
                )
            }
        }

        do {
            var result = try await registry.execute(
                call,
                workspace: workspace
            )
            let state = Recovery.State(
                reconciled:
                    preflight.risk.isMutating
                    ? .applied
                    : .none
            )

            recovery.state = state
            recovery.attempts.append(
                Recovery.Attempt(
                    number: attemptNumber,
                    action: decision.action,
                    status: .succeeded,
                    state: state
                )
            )

            result.recovery = recovery.record(
                outcome: .recovered
            )
            return .complete(
                result
            )
        } catch {
            let accepted = recovery.absorb(
                error
            )

            recovery.attempts.append(
                Recovery.Attempt(
                    capturing: error,
                    number: attemptNumber,
                    action: decision.action,
                    state: recovery.state
                )
            )

            guard accepted else {
                return .complete(
                    ToolExecutionResult(
                        result: try makeErrorResult(
                            for: call,
                            error: error
                        ),
                        recovery: recovery.record(
                            outcome: .failed
                        )
                    )
                )
            }

            guard RecoveryState.allows(
                decision.action,
                state: recovery.state
            ) else {
                return .complete(
                    ToolExecutionResult(
                        result: try makeErrorResult(
                            for: call,
                            error: error
                        ),
                        recovery: recovery.record(
                            outcome: .failed
                        )
                    )
                )
            }

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
