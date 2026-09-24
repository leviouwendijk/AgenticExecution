import Agentic
import AgenticExecution
import Foundation
import TestFlows
import Version

private struct PreparedIntentOperationFixture:
    AgentPreparedOperation
{
    struct Plan:
        Sendable,
        Codable,
        Hashable
    {
        let value: String
    }

    struct Result:
        Sendable,
        Codable,
        Hashable
    {
        let value: String
    }

    static let schema = PreparedOperation.Schema(
        identifier: "fixture.prepared_intent_operation",
        version: ObjectVersion(
            major: 0,
            minor: 1,
            patch: 0
        )
    )

    func execute(
        _ plan: Plan,
        context _: PreparedOperation.Context
    ) async throws -> Result {
        .init(
            value: "executed:\(plan.value)"
        )
    }
}

private actor PreparedIntentOperationStore:
    PreparedIntentStore
{
    private var intents:
        [PreparedIntentIdentifier: PreparedIntent] = [:]

    func load(
        id: PreparedIntentIdentifier
    ) async throws -> PreparedIntent? {
        intents[id]
    }

    func list() async throws -> [PreparedIntent] {
        Array(
            intents.values
        )
    }

    func save(
        _ intent: PreparedIntent
    ) async throws {
        intents[intent.id] = intent
    }

    func delete(
        id: PreparedIntentIdentifier
    ) async throws {
        intents.removeValue(
            forKey: id
        )
    }
}

extension AgenticExecutionFlowTesting {
    static func runPreparedIntentOperationAuthority()
        async throws
        -> [TestDiagnostic]
    {
        let operation = try PreparedIntentOperationFixture.envelope(
            .init(
                value: "approved-plan"
            )
        )
        let expiresAt = Date().addingTimeInterval(
            3_600
        )
        let manager = PreparedIntentManager(
            store: PreparedIntentOperationStore()
        )
        let created = try await manager.create(
            .init(
                sessionID: "  fixture-session  ",
                operation: operation,
                reviewPayload: .init(
                    title: "  Review operation  ",
                    summary: "  Review the exact prepared operation.  ",
                    risk: .boundedmutate,
                    target: "fixture-target",
                    expectedSideEffects: [
                        "mutates fixture state",
                    ],
                    policyChecks: [
                        "exact prepared operation approved",
                    ],
                    metadata: [
                        "surface": "test_flow",
                    ]
                ),
                expiresAt: expiresAt,
                idempotencyKey: "  fixture-idempotency  ",
                metadata: [
                    "source": "prepared-intent-operation-authority",
                ]
            )
        )

        try Expect.equal(
            created.operation,
            operation,
            "prepared intent retains one authoritative prepared-operation envelope"
        )
        try Expect.equal(
            created.sessionID,
            "fixture-session",
            "prepared intent manager normalizes session identity"
        )
        try Expect.equal(
            created.reviewPayload.title,
            "Review operation",
            "prepared intent manager normalizes review title without changing operation authority"
        )
        try Expect.equal(
            created.reviewPayload.summary,
            "Review the exact prepared operation.",
            "prepared intent manager normalizes review summary without changing operation authority"
        )
        try Expect.equal(
            created.expiresAt,
            expiresAt,
            "prepared intent owns expiry as lifecycle state outside review presentation"
        )

        let restored = try JSONDecoder().decode(
            PreparedIntent.self,
            from: JSONEncoder().encode(
                created
            )
        )

        try Expect.equal(
            restored,
            created,
            "prepared intent survives durable Codable round trip with its operation envelope"
        )

        let restoredPlan = try PreparedIntentOperationFixture.plan(
            from: restored.operation
        )

        try Expect.equal(
            restoredPlan,
            .init(
                value: "approved-plan"
            ),
            "prepared intent operation envelope is the sole durable source of the exact typed Plan"
        )

        let matching = try await manager.list(
            operationIdentifier: PreparedIntentOperationFixture
                .schema
                .identifier
        )

        try Expect.equal(
            matching.map(\.id),
            [
                created.id,
            ],
            "prepared intent listing derives operation identity from the authoritative envelope"
        )

        let approved = try await manager.review(
            id: created.id,
            decision: .approve,
            reviewer: "fixture-reviewer"
        )

        try Expect.equal(
            approved.status,
            .approved,
            "prepared intent remains reviewable independently of operation execution"
        )
        try Expect.equal(
            approved.reviewedAt,
            Optional(
                approved.updatedAt
            ),
            "review lifecycle updates the durable intent timestamp"
        )

        let resultEnvelope = try PreparedIntentOperationFixture
            .resultEnvelope(
                .init(
                    value: "execution-result"
                )
            )
        let executed = try await manager.markExecutionSucceeded(
            id: created.id,
            summary: "Fixture operation executed.",
            result: resultEnvelope
        )

        try Expect.equal(
            executed.status,
            .executed,
            "successful prepared operation execution resolves the intent lifecycle"
        )
        try Expect.equal(
            executed.executionRecord?.operation,
            operation.schema,
            "execution record snapshots the exact approved operation schema as evidence"
        )
        try Expect.equal(
            executed.executionResult,
            resultEnvelope,
            "execution record retains the versioned typed-result envelope"
        )
        try Expect.equal(
            executed.executedAt,
            Optional(
                executed.updatedAt
            ),
            "execution lifecycle updates the durable intent timestamp from execution evidence"
        )

        let mismatchIntent = try await manager.create(
            .init(
                operation: operation,
                reviewPayload: .init(
                    title: "Mismatch",
                    summary: "Reject mismatched result schema.",
                    risk: .observe
                )
            )
        )
        _ = try await manager.review(
            id: mismatchIntent.id,
            decision: .approve
        )

        let incompatibleSchema = PreparedOperation.Schema(
            identifier: PreparedIntentOperationFixture
                .schema
                .identifier,
            version: ObjectVersion(
                major: 0,
                minor: 2,
                patch: 0
            )
        )
        let incompatibleResult = PreparedOperation.ResultEnvelope(
            schema: incompatibleSchema,
            result: resultEnvelope.result
        )
        var mismatchedResultRejected = false

        do {
            _ = try await manager.markExecutionSucceeded(
                id: mismatchIntent.id,
                summary: "Must not persist.",
                result: incompatibleResult
            )
        } catch PreparedIntentError.executionResultSchemaMismatch(
            let expected,
            let actual
        ) {
            mismatchedResultRejected = true

            try Expect.equal(
                expected,
                operation.schema,
                "result mismatch reports the approved operation schema"
            )
            try Expect.equal(
                actual,
                incompatibleSchema,
                "result mismatch reports the incompatible result schema"
            )
        }

        try Expect.equal(
            mismatchedResultRejected,
            true,
            "prepared intent refuses execution evidence authored for another operation schema version"
        )
        let mismatchAfterRejection = try await manager.get(
            mismatchIntent.id
        )

        try Expect.equal(
            mismatchAfterRejection.status,
            .approved,
            "rejected execution evidence does not mutate the prepared-intent lifecycle"
        )

        let pendingExpired = try await manager.create(
            .init(
                operation: operation,
                reviewPayload: .init(
                    title: "Pending expiry",
                    summary: "Prove executableIntent resolves expiry.",
                    risk: .observe
                ),
                expiresAt: Date().addingTimeInterval(
                    -1
                )
            )
        )
        var expiryRejected = false

        do {
            _ = try await manager.executableIntent(
                id: pendingExpired.id
            )
        } catch PreparedIntentError.expired(
            let id
        ) {
            expiryRejected = true

            try Expect.equal(
                id,
                pendingExpired.id,
                "expiry failure identifies the durable prepared intent"
            )
        }

        try Expect.equal(
            expiryRejected,
            true,
            "prepared intent lifecycle owns expiry independently of review payload"
        )
        let expiredAfterRejection = try await manager.get(
            pendingExpired.id
        )

        try Expect.equal(
            expiredAfterRejection.status,
            .expired,
            "expired prepared intent persists terminal expiry state"
        )

        return [
            .field(
                "operation",
                operation.schema.identifier.rawValue
            ),
            .field(
                "version",
                operation.schema.version.string(
                    prefixStyle: .none
                )
            ),
            .field(
                "result_schema",
                resultEnvelope.schema.identifier.rawValue
            ),
            .field(
                "mismatch_rejected",
                String(mismatchedResultRejected)
            ),
            .field(
                "expiry_owned_by_intent",
                String(expiryRejected)
            ),
        ]
    }
}
