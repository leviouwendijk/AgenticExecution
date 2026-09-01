import Agentic

enum AgentToolPlanSingleStepTraversal:
    Sendable
{
    case next(AgentToolPlanSingleStep)
    case complete(AgentToolPlanOutcome)
}

enum AgentToolPlanSingleStepHistory {
    static func outcomesByPath(
        attempts: [AgentToolPlanAttempt],
        resolutions: [AgentToolPlanResolution] = []
    ) -> [String: AgentToolPlanOutcome] {
        var attemptOutcomes: [String: AgentToolPlanOutcome] = [:]

        for attempt in attempts {
            for record in attempt.result.records
            where record.invocation != nil
                || record.outcome != .skipped
            {
                attemptOutcomes[record.path] = record.outcome
            }
        }

        var outcomes = attemptOutcomes

        for resolution in resolutions {
            switch resolution.kind {
            case .skipped:
                outcomes[resolution.path] = .skipped

            case .retried:
                if let outcome = attemptOutcomes[resolution.path] {
                    outcomes[resolution.path] = outcome
                }
            }
        }

        return outcomes
    }

    static func containsRecordedCall(
        path: String,
        callID: String,
        attempts: [AgentToolPlanAttempt],
        resolutions: [AgentToolPlanResolution] = []
    ) -> Bool {
        for attempt in attempts {
            if attempt.result.records.contains(
                where: { record in
                    record.path == path
                        && record.call.id == callID
                        && (
                            record.invocation != nil
                                || record.outcome != .skipped
                        )
                }
            ) {
                return true
            }
        }

        return resolutions.contains {
            resolution in

            resolution.path == path
                && resolution.callID == callID
        }
    }
}

extension AgentToolPlanNode {
    func singleStepTraversal(
        path: String,
        outcomesByPath: [String: AgentToolPlanOutcome]
    ) -> AgentToolPlanSingleStepTraversal {
        switch self {
        case .call(
            let call,
            let execution,
            let onSuccess,
            let onFailure,
            let onDenied
        ):
            guard let outcome = outcomesByPath[path] else {
                return .next(
                    AgentToolPlanSingleStep(
                        path: path,
                        call: call,
                        node: .call(
                            call,
                            execution: execution
                        )
                    )
                )
            }

            let selectedLabel: String?
            let selectedNodes: [AgentToolPlanNode]

            switch outcome {
            case .succeeded:
                selectedLabel = "onSuccess"
                selectedNodes = onSuccess

            case .failed:
                selectedLabel = "onFailure"
                selectedNodes = onFailure

            case .denied:
                selectedLabel = "onDenied"
                selectedNodes = onDenied

            case .needs_human_review,
                 .skipped,
                 .mixed:
                selectedLabel = nil
                selectedNodes = []
            }

            let selectedOutcome: AgentToolPlanOutcome

            if let selectedLabel {
                let branch = AgentToolPlanNode.sequence(
                    selectedNodes
                ).singleStepTraversal(
                    path: "\(path).\(selectedLabel)",
                    outcomesByPath: outcomesByPath
                )

                switch branch {
                case .next:
                    return branch

                case .complete(let outcome):
                    selectedOutcome = outcome
                }
            } else {
                selectedOutcome = .succeeded
            }

            return .complete(
                singleStepFinalOutcome(
                    outcome: outcome,
                    selectedOutcome: selectedOutcome
                )
            )

        case .sequence(let children):
            for (
                index,
                child
            ) in children.enumerated() {
                let childTraversal = child.singleStepTraversal(
                    path: "\(path).sequence[\(index)]",
                    outcomesByPath: outcomesByPath
                )

                switch childTraversal {
                case .next:
                    return childTraversal

                case .complete(let outcome):
                    guard outcome == .succeeded else {
                        return .complete(
                            outcome
                        )
                    }
                }
            }

            return .complete(
                .succeeded
            )

        case .batch(let children):
            var outcomes: [AgentToolPlanOutcome] = []

            for (
                index,
                child
            ) in children.enumerated() {
                let childTraversal = child.singleStepTraversal(
                    path: "\(path).batch[\(index)]",
                    outcomesByPath: outcomesByPath
                )

                switch childTraversal {
                case .next:
                    return childTraversal

                case .complete(let outcome):
                    outcomes.append(
                        outcome
                    )

                    if outcome == .needs_human_review {
                        return .complete(
                            .needs_human_review
                        )
                    }
                }
            }

            return .complete(
                singleStepAggregate(
                    outcomes
                )
            )
        }
    }

    private func singleStepFinalOutcome(
        outcome: AgentToolPlanOutcome,
        selectedOutcome: AgentToolPlanOutcome
    ) -> AgentToolPlanOutcome {
        switch outcome {
        case .succeeded:
            return selectedOutcome

        case .failed,
             .denied:
            return selectedOutcome == .needs_human_review
                ? .needs_human_review
                : outcome

        case .needs_human_review:
            return .needs_human_review

        case .skipped:
            return .succeeded

        case .mixed:
            return .mixed
        }
    }

    private func singleStepAggregate(
        _ outcomes: [AgentToolPlanOutcome]
    ) -> AgentToolPlanOutcome {
        guard let first = outcomes.first else {
            return .succeeded
        }

        return outcomes.dropFirst().allSatisfy {
            $0 == first
        }
            ? first
            : .mixed
    }
}

func agentToolPlanSingleStepParentState(
    traversal: AgentToolPlanSingleStepTraversal,
    after step: AgentToolPlanSingleStep,
    attemptNumber: Int
) -> AgentToolPlanRunState {
    switch traversal {
    case .next:
        return .paused(
            AgentToolPlanPause(
                afterPath: step.path,
                afterCallID: step.call.id,
                attemptNumber: attemptNumber,
                reason: .single_step
            )
        )

    case .complete(.succeeded):
        return .completed

    case .complete(let outcome):
        return .stopped(
            outcome
        )
    }
}
