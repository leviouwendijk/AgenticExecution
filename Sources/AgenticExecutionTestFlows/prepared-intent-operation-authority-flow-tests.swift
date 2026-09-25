import Agentic
import AgenticExecution
import Foundation
import TestFlows
import Version

private enum PreparedIntentOperationFlowError: Error {
    case missingExecutionResult
    case rejectedSave(PreparedIntentStatus)
}

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
    private let rejectedSaveStatus: PreparedIntentStatus?
    private var intents:
        [PreparedIntentIdentifier: PreparedIntent] = [:]
    private var statusHistory:
        [PreparedIntentIdentifier: [PreparedIntentStatus]] = [:]

    init(
        rejectedSaveStatus: PreparedIntentStatus? = nil
    ) {
        self.rejectedSaveStatus = rejectedSaveStatus
    }

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
        if intent.status == rejectedSaveStatus {
            throw PreparedIntentOperationFlowError.rejectedSave(
                intent.status
            )
        }

        intents[intent.id] = intent
        statusHistory[
            intent.id,
            default: []
        ].append(
            intent.status
        )
    }

    func delete(
        id: PreparedIntentIdentifier
    ) async throws {
        intents.removeValue(
            forKey: id
        )
        statusHistory.removeValue(
            forKey: id
        )
    }

    func statuses(
        for id: PreparedIntentIdentifier
    ) -> [PreparedIntentStatus] {
        statusHistory[id] ?? []
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
        let tool = ToolIdentifier(
            rawValue: "fixture_prepared_intent_operation"
        )
        let preflight = ToolPreflight(
            tool: tool,
            risk: .boundedmutate,
            summary: "Review the exact prepared operation.",
            access: .init(
                targets: [
                    "fixture-target",
                ]
            ),
            sideEffects: [
                "mutates fixture state",
            ],
            policyChecks: [
                "exact prepared operation approved",
            ]
        )
        let review = ToolInvocation.Review(
            call: .init(
                id: "fixture-prepared-intent-call",
                tool: tool,
                input: .object([:])
            ),
            preflight: preflight,
            requirement: .needs_human_review
        )
        let prepared = ToolInvocation.Prepared(
            review: review,
            operation: operation
        )
        let expiresAt = Date().addingTimeInterval(
            3_600
        )
        let store = PreparedIntentOperationStore()
        let manager = PreparedIntentManager(
            store: store
        )
        let created = try await manager.create(
            .init(
                sessionID: "  fixture-session  ",
                invocation: prepared,
                expiresAt: expiresAt,
                idempotencyKey: "  fixture-idempotency  ",
                metadata: [
                    "source": "prepared-intent-operation-authority",
                ]
            )
        )

        try Expect.equal(
            created.invocation,
            prepared,
            "prepared intent retains one authoritative prepared ToolInvocation"
        )
        try Expect.equal(
            created.invocation.review,
            review,
            "prepared invocation persists the complete governed ToolInvocation review"
        )
        try Expect.equal(
            created.operation,
            operation,
            "prepared intent exposes the exact prepared-operation envelope from its invocation"
        )
        try Expect.equal(
            created.preflight,
            preflight,
            "prepared intent exposes canonical ToolPreflight from its governed review"
        )
        try Expect.equal(
            created.sessionID,
            "fixture-session",
            "prepared intent manager normalizes session identity"
        )
        try Expect.equal(
            created.expiresAt,
            expiresAt,
            "prepared intent owns expiry as lifecycle state outside prepared invocation semantics"
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
            "prepared intent survives durable Codable round trip with its full governed invocation"
        )

        let restoredPlan = try PreparedIntentOperationFixture.plan(
            from: restored.operation
        )

        try Expect.equal(
            restoredPlan,
            .init(
                value: "approved-plan"
            ),
            "prepared invocation operation envelope is the sole durable source of the exact typed Plan"
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
            "prepared intent listing derives operation identity from the authoritative prepared invocation"
        )

        let approved = try await manager.review(
            id: created.id,
            decision: .approve,
            reviewer: "fixture-reviewer"
        )

        try Expect.equal(
            approved.status,
            .approved,
            "prepared intent lifecycle remains independently reviewable"
        )
        try Expect.equal(
            approved.reviewedAt,
            Optional(
                approved.updatedAt
            ),
            "review lifecycle updates the durable intent timestamp"
        )

        var registry = PreparedOperationRegistry()

        try registry.register(
            PreparedIntentOperationFixture()
        )

        let executed = try await manager.execute(
            id: created.id,
            using: registry,
            context: .init(
                metadata: [
                    "flow": "prepared-intent-operation-authority",
                ]
            )
        )

        guard let resultEnvelope = executed.executionResult else {
            throw PreparedIntentOperationFlowError.missingExecutionResult
        }

        let typedResult = try PreparedIntentOperationFixture.result(
            from: resultEnvelope
        )

        try Expect.equal(
            typedResult,
            .init(
                value: "executed:approved-plan"
            ),
            "PreparedIntentManager executes the exact stored prepared operation through the Execution registry"
        )
        try Expect.equal(
            executed.status,
            .executed,
            "successful prepared invocation execution resolves the intent lifecycle"
        )
        try Expect.equal(
            executed.executionRecord?.operation,
            operation.schema,
            "execution record snapshots the exact approved operation schema as evidence"
        )
        try Expect.equal(
            executed.executedAt,
            Optional(
                executed.updatedAt
            ),
            "execution lifecycle updates the durable intent timestamp from execution evidence"
        )

        let executionStatuses = await store.statuses(
            for: created.id
        )

        try Expect.equal(
            executionStatuses,
            [
                .pending_review,
                .approved,
                .executing,
                .executed,
            ],
            "execution persists an executing claim before the external operation and final evidence"
        )

        let mismatchIntent = try await manager.create(
            .init(
                invocation: prepared
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

        let persistenceStore = PreparedIntentOperationStore(
            rejectedSaveStatus: .executed
        )
        let persistenceManager = PreparedIntentManager(
            store: persistenceStore
        )
        let persistenceIntent = try await persistenceManager.create(
            .init(
                invocation: prepared
            )
        )
        _ = try await persistenceManager.review(
            id: persistenceIntent.id,
            decision: .approve
        )
        var persistenceFailureObserved = false

        do {
            _ = try await persistenceManager.execute(
                id: persistenceIntent.id,
                using: registry
            )
        } catch PreparedIntentOperationFlowError.rejectedSave(
            let status
        ) {
            persistenceFailureObserved = true

            try Expect.equal(
                status,
                .executed,
                "execution completion surfaces the final persistence failure instead of relabeling it as operation failure"
            )
        }

        try Expect.equal(
            persistenceFailureObserved,
            true,
            "prepared execution surfaces failure to persist final success evidence"
        )

        let uncertainIntent = try await persistenceManager.get(
            persistenceIntent.id
        )

        try Expect.equal(
            uncertainIntent.status,
            .executing,
            "failed final evidence persistence leaves durable state executing instead of making the operation eligible for replay"
        )

        var replayRejected = false

        do {
            _ = try await persistenceManager.execute(
                id: persistenceIntent.id,
                using: registry
            )
        } catch PreparedIntentError.notApproved(
            let id,
            let status
        ) {
            replayRejected = true

            try Expect.equal(
                id,
                persistenceIntent.id,
                "replay rejection identifies the prepared intent whose execution state is unresolved"
            )
            try Expect.equal(
                status,
                .executing,
                "an unresolved executing intent cannot be executed a second time"
            )
        }

        try Expect.equal(
            replayRejected,
            true,
            "executing durable state blocks accidental replay after uncertain persistence"
        )

        var reviewDuringExecutionRejected = false

        do {
            _ = try await persistenceManager.review(
                id: persistenceIntent.id,
                decision: .deny
            )
        } catch PreparedIntentError.notReviewable(
            let id,
            let status
        ) {
            reviewDuringExecutionRejected = true

            try Expect.equal(
                id,
                persistenceIntent.id,
                "review rejection identifies the prepared intent currently executing"
            )
            try Expect.equal(
                status,
                .executing,
                "executing durable state cannot be overwritten by a later review decision"
            )
        }

        try Expect.equal(
            reviewDuringExecutionRejected,
            true,
            "executing prepared intents are not reviewable"
        )

        let pendingExpired = try await manager.create(
            .init(
                invocation: prepared,
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
            "prepared intent lifecycle owns expiry independently of prepared invocation state"
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
                "executing_claim_persisted",
                String(
                    executionStatuses.contains(
                        .executing
                    )
                )
            ),
            .field(
                "persistence_failure_safe",
                String(persistenceFailureObserved)
            ),
            .field(
                "replay_rejected",
                String(replayRejected)
            ),
            .field(
                "expiry_owned_by_intent",
                String(expiryRejected)
            ),
        ]
    }
}
