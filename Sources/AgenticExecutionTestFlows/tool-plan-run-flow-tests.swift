import Agentic
import AgenticExecution
import Foundation
import Primitives
import TestFlows

enum AgenticExecutionFlowTesting {
    static func runToolPlanSuspensionAndRetry() async throws -> [TestFlowDiagnostic] {
        let probe = RetriableToolProbe()

        let tool = ClosureAgentTool(
            identifier: "tool_plan_retry_probe",
            description: "Fails its first invocation and succeeds thereafter."
        ) { value, _ in
            try await probe.invoke(
                value
            )
        }

        let invoker = ToolInvoker(
            registry: ToolRegistry(
                tools: [
                    tool,
                ]
            ),
            policy: ToolExecutionPolicy(
                autonomyMode: .auto_observe
            )
        )

        let input = try JSONToolBridge.encode(
            RetryProbeInput(
                marker: "retry"
            )
        )

        let first = AgentToolCall(
            id: "retry-first",
            name: "tool_plan_retry_probe",
            input: input
        )

        let pending = AgentToolCall(
            id: "retry-pending",
            name: "tool_plan_retry_probe",
            input: input
        )

        let plan = AgentToolPlan(
            id: "resumable-plan-probe",
            root: .sequence(
                [
                    .call(first),
                    .call(pending),
                ]
            )
        )

        let executor = AgentToolPlanRunExecutor(
            invoker: invoker
        )

        let initial = try await executor.start(
            plan,
            runID: "resumable-run-probe"
        )

        guard case .suspended(let suspension) = initial.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            suspension.path,
            "root.sequence[0]",
            "initial suspension path"
        )

        try Expect.equal(
            suspension.callID,
            first.id,
            "initial suspended call"
        )

        try Expect.equal(
            suspension.attemptNumber,
            1,
            "initial suspension attempt"
        )

        guard let initialResult = initial.latestResult else {
            throw AgenticExecutionFlowError.missingResult
        }

        let initialOutcomes: [AgentToolPlanOutcome] =
            initialResult.records.map { record in
                record.outcome
            }

        try Expect.equal(
            initialOutcomes,
            [
                .failed,
                .skipped,
            ],
            "one-shot executor records blocked suffix"
        )

        try Expect.equal(
            await probe.invocationCount(),
            1,
            "pending parent node did not execute after failure"
        )

        let retried = try await executor.retry(
            initial
        )

        guard case .recovered(let recovery) = retried.state else {
            throw AgenticExecutionFlowError.unexpectedRunState
        }

        try Expect.equal(
            recovery.path,
            suspension.path,
            "recovered original path"
        )

        try Expect.equal(
            recovery.callID,
            suspension.callID,
            "recovered original call"
        )

        try Expect.equal(
            recovery.resolvedAttemptNumber,
            2,
            "retry attempt number"
        )

        let attemptNumbers: [Int] =
            retried.attempts.map { attempt in
                attempt.number
            }

        try Expect.equal(
            attemptNumbers,
            [
                1,
                2,
            ],
            "attempt history retained"
        )

        try Expect.equal(
            retried.revision,
            2,
            "run revision follows attempt history"
        )

        try Expect.equal(
            retried.plan,
            plan,
            "semantic parent plan remains unchanged"
        )

        try Expect.equal(
            await probe.invocationCount(),
            2,
            "successful retry does not automatically resume pending parent suffix"
        )

        let encoded = try JSONEncoder().encode(
            retried
        )

        let decoded = try JSONDecoder().decode(
            AgentToolPlanRun.self,
            from: encoded
        )

        try Expect.equal(
            decoded,
            retried,
            "tool-plan run codable round trip"
        )

        let relationship = AgentToolPlanRunRelationship.recovery(
            parentRunID: retried.id
        )

        let relationshipData = try JSONEncoder().encode(
            relationship
        )

        let decodedRelationship = try JSONDecoder().decode(
            AgentToolPlanRunRelationship.self,
            from: relationshipData
        )

        try Expect.equal(
            decodedRelationship,
            relationship,
            "recovery relationship codable round trip"
        )

        return [
            .field(
                "state",
                "recovered"
            ),
            .field(
                "attempts",
                "\(retried.attempts.count)"
            ),
            .field(
                "revision",
                "\(retried.revision)"
            ),
        ]
    }
}

private actor RetriableToolProbe {
    private var count = 0

    func invoke(
        _ value: JSONValue
    ) throws -> JSONValue {
        count += 1

        if count == 1 {
            throw RetryProbeError.firstAttempt
        }

        return value
    }

    func invocationCount() -> Int {
        count
    }
}

private struct RetryProbeInput:
    Sendable,
    Codable,
    Hashable
{
    let marker: String
}

private enum RetryProbeError: Error {
    case firstAttempt
}

private enum AgenticExecutionFlowError: Error {
    case missingResult
    case unexpectedRunState
}
