import Agentic
import Workspace

internal struct ToolExecution: Sendable {
    internal let registry: ToolRegistry
    internal let recovery: Recovery.Policy?
    internal let workspace: WorkspaceContext?

    internal init(
        registry: ToolRegistry,
        recovery: Recovery.Policy? = nil,
        workspace: WorkspaceContext? = nil
    ) {
        self.registry = registry
        self.recovery = recovery
        self.workspace = workspace
    }

    internal func execute(
        _ call: ToolCall,
        preflight: ToolPreflight
    ) async throws -> ToolExecutionResult {
        do {
            return try await registry.execute(
                call,
                workspace: workspace
            )
        } catch {
            let propagatedRecovery: Recovery.Record?

            if let toolError = error as? ToolCall.Error,
               let incident = toolError.failure.incident
            {
                propagatedRecovery = Recovery.Record(
                    incident: incident,
                    plan: nil,
                    attempts: [],
                    outcome: .propagated
                )
            } else {
                propagatedRecovery = nil
            }

            guard var recovery = RecoveryState(
                error: error,
                policy: recovery
            ) else {
                return ToolExecutionResult(
                    result: try makeErrorResult(
                        for: call,
                        error: error
                    ),
                    failure:
                        (error as? ToolCall.Error)?
                            .failure,
                    recovery: propagatedRecovery
                )
            }

            while let decision = recovery.decision {
                guard RecoveryState.allows(
                    decision.action,
                    state: recovery.state
                ) else {
                    let recoveryError =
                        Error.action_unsupported(
                            decision.action
                        )

                    return ToolExecutionResult(
                        result: try makeErrorResult(
                            for: call,
                            error: recoveryError
                        ),
                        recovery: recovery.record(
                            outcome: .failed
                        )
                    )
                }

                guard let permit = decision.limit.nextAttempt(
                    after: recovery.completedAttemptsInStep
                ) else {
                    let recoveryError =
                        Error.recovery_exhausted

                    return ToolExecutionResult(
                        result: try makeErrorResult(
                            for: call,
                            error: recoveryError
                        ),
                        recovery: recovery.record(
                            outcome: .exhausted
                        )
                    )
                }

                recovery.completedAttemptsInStep += 1

                let outcome: ActionOutcome

                switch decision.action {
                case .reconcile:
                    outcome = try await reconcile(
                        call,
                        decision: decision,
                        attemptNumber: permit.number,
                        recovery: &recovery
                    )

                case .retry_same_operation:
                    outcome = try await retrySameOperation(
                        call,
                        preflight: preflight,
                        decision: decision,
                        attemptNumber: permit.number,
                        recovery: &recovery
                    )

                default:
                    let recoveryError =
                        Error.action_unsupported(
                            decision.action
                        )

                    recovery.attempts.append(
                        Recovery.Attempt(
                            capturing: recoveryError,
                            number: permit.number,
                            action: decision.action,
                            state: recovery.state
                        )
                    )

                    outcome = .complete(
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

                switch outcome {
                case .complete(let result):
                    return result

                case .continueRecovery:
                    continue
                }
            }

            let recoveryError =
                Error.recovery_exhausted

            return ToolExecutionResult(
                result: try makeErrorResult(
                    for: call,
                    error: recoveryError
                ),
                recovery: recovery.record(
                    outcome: .exhausted
                )
            )
        }
    }
}

extension ToolExecution {
    enum ActionOutcome {
        case complete(ToolExecutionResult)
        case continueRecovery
    }
}
