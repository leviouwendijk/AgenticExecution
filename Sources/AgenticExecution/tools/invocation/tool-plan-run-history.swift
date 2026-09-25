import Agentic

extension ToolPlan.Run {
    enum History {
        static func outcomesByPath(
            attempts: [ToolPlan.Run.Attempt],
            resolutions: [ToolPlan.Run.Resolution] = []
        ) -> [String: ToolPlan.Outcome] {
            var attemptOutcomes: [String: ToolPlan.Outcome] = [:]

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
            attempts: [ToolPlan.Run.Attempt],
            resolutions: [ToolPlan.Run.Resolution] = []
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
}
