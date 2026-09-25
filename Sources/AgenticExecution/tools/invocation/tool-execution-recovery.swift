import Agentic

extension ToolExecution {
    struct RecoveryState {
        let incident: Recovery.Incident
        let plan: Recovery.Plan
        var failure: ToolCall.Failure
        var attempts: [Recovery.Attempt]
        var state: Recovery.State
        var stepIndex: Int
        var completedAttemptsInStep: UInt

        init?(
            error: any Swift.Error,
            policy: Recovery.Policy?
        ) {
            guard
                let error = error as? ToolCall.Error,
                error.failure.phase == .call,
                let incident = error.failure.incident,
                let plan = policy?.plan(
                    for: incident
                ),
                let first = plan.steps.first,
                Self.allows(
                    first.action,
                    state: incident.state
                )
            else {
                return nil
            }

            self.incident = incident
            self.plan = plan
            self.failure = error.failure
            self.attempts = []
            self.state = incident.state
            self.stepIndex = 0
            self.completedAttemptsInStep = 0
        }

        var decision: Recovery.Decision? {
            guard plan.steps.indices.contains(stepIndex) else {
                return nil
            }

            return Recovery.Decision(
                step: plan.steps[stepIndex]
            )
        }

        mutating func advance(
            to state: Recovery.State
        ) {
            self.state = state
            stepIndex += 1
            completedAttemptsInStep = 0
        }

        mutating func absorb(
            _ error: any Swift.Error
        ) -> Bool {
            guard
                let error = error as? ToolCall.Error,
                error.failure.phase == .call,
                let incident = error.failure.incident,
                incident.kind == self.incident.kind,
                incident.stage == self.incident.stage,
                incident.scope == self.incident.scope
            else {
                return false
            }

            failure = error.failure
            state = incident.state
            return true
        }

        func record(
            outcome: Recovery.Outcome
        ) -> Recovery.Record {
            Recovery.Record(
                incident: incident,
                plan: plan,
                attempts: attempts,
                state: state,
                outcome: outcome
            )
        }

        static func allows(
            _ action: Recovery.Action,
            state: Recovery.State
        ) -> Bool {
            switch action {
            case .reconcile:
                return state.effect == .unknown
                    && state.retry == .requires_reconciliation

            case .retry_same_operation:
                return state.retry == .safe
                    && (
                        state.effect == .none
                        || state.effect == .not_applied
                    )

            default:
                return false
            }
        }
    }
}
