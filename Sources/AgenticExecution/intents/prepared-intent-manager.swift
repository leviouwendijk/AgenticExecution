import Agentic
import Foundation
import Primitives

public actor PreparedIntentManager {
    public let store: any PreparedIntentStore

    public init(
        store: any PreparedIntentStore
    ) {
        self.store = store
    }

    public func create(
        _ draft: PreparedIntentDraft
    ) async throws -> PreparedIntent {
        let actionType = try normalizedRequired(
            draft.actionType,
            error: .emptyActionType
        )
        let title = try normalizedRequired(
            draft.reviewPayload.title,
            error: .emptyTitle
        )
        let summary = try normalizedRequired(
            draft.reviewPayload.summary,
            error: .emptySummary
        )

        var payload = draft.reviewPayload
        payload.title = title
        payload.summary = summary
        payload.actionType = normalized(
            payload.actionType
        ) ?? actionType

        let intent = PreparedIntent(
            sessionID: normalized(
                draft.sessionID
            ),
            actionType: actionType,
            reviewPayload: payload,
            executionToolName: normalized(
                draft.executionToolName
            ),
            idempotencyKey: normalized(
                draft.idempotencyKey
            ),
            metadata: draft.metadata
        )

        try await store.save(
            intent
        )

        return intent
    }

    public func get(
        _ id: PreparedIntentIdentifier
    ) async throws -> PreparedIntent {
        guard let intent = try await store.load(
            id: id
        ) else {
            throw PreparedIntentError.intentNotFound(
                id
            )
        }

        return intent
    }

    public func list(
        statuses: [PreparedIntentStatus] = [],
        sessionID: String? = nil,
        actionType: String? = nil,
        includeExpired: Bool = false
    ) async throws -> [PreparedIntent] {
        let sessionID = normalized(
            sessionID
        )
        let actionType = normalized(
            actionType
        )

        return try await store.list().filter { intent in
            if !includeExpired,
               intent.isExpired(),
               intent.status != .expired {
                return false
            }

            if !statuses.isEmpty,
               !statuses.contains(intent.status) {
                return false
            }

            if let sessionID,
               intent.sessionID != sessionID {
                return false
            }

            if let actionType,
               intent.actionType != actionType {
                return false
            }

            return true
        }
    }

    public func review(
        id: PreparedIntentIdentifier,
        decision: PreparedIntentReviewDecision,
        reviewer: String? = nil,
        note: String? = nil
    ) async throws -> PreparedIntent {
        var intent = try await get(
            id
        )

        guard !intent.status.isTerminal else {
            throw PreparedIntentError.alreadyTerminal(
                id,
                intent.status
            )
        }

        if intent.isExpired(),
           decision == .approve {
            intent.status = .expired
            intent.reviewedAt = Date()
            intent.reviewedBy = normalized(
                reviewer
            )
            intent.reviewNote = normalized(
                note
            )

            try await store.save(
                intent
            )

            throw PreparedIntentError.expired(
                id
            )
        }

        intent.status = decision.resolvedStatus
        intent.reviewedAt = Date()
        intent.reviewedBy = normalized(
            reviewer
        )
        intent.reviewNote = normalized(
            note
        )

        try await store.save(
            intent
        )

        return intent
    }

    public func executableIntent(
        id: PreparedIntentIdentifier,
        now: Date = Date()
    ) async throws -> PreparedIntent {
        var intent = try await get(
            id
        )

        if intent.isExpired(
            at: now
        ) {
            intent.status = .expired

            try await store.save(
                intent
            )

            throw PreparedIntentError.expired(
                id
            )
        }

        guard intent.status == .approved else {
            throw PreparedIntentError.notApproved(
                id,
                intent.status
            )
        }

        return intent
    }

    public func recordExecution(
        id: PreparedIntentIdentifier,
        record: PreparedIntentExecutionRecord
    ) async throws -> PreparedIntent {
        let intent = try await executableIntent(
            id: id
        )

        return try await recordExecution(
            intent: intent,
            id: id,
            record: record
        )
    }

    public func markExecuted(
        id: PreparedIntentIdentifier,
        result: JSONValue? = nil
    ) async throws -> PreparedIntent {
        try await markExecutionSucceeded(
            id: id,
            summary: "Prepared intent executed.",
            result: result
        )
    }

    public func markExecutionSucceeded(
        id: PreparedIntentIdentifier,
        summary: String,
        result: JSONValue? = nil,
        metadata: [String: String] = [:]
    ) async throws -> PreparedIntent {
        let intent = try await executableIntent(
            id: id
        )
        let summary = try normalizedRequired(
            summary,
            error: .emptyExecutionSummary
        )
        let now = Date()

        return try await recordExecution(
            intent: intent,
            id: id,
            record: .init(
                intentID: id,
                executionToolName: intent.executionToolName,
                status: .succeeded,
                summary: summary,
                startedAt: now,
                completedAt: now,
                result: result,
                metadata: metadata
            )
        )
    }

    public func markExecutionFailed(
        id: PreparedIntentIdentifier,
        summary: String,
        errorMessage: String? = nil,
        result: JSONValue? = nil,
        metadata: [String: String] = [:]
    ) async throws -> PreparedIntent {
        let intent = try await executableIntent(
            id: id
        )
        let summary = try normalizedRequired(
            summary,
            error: .emptyExecutionSummary
        )
        let now = Date()

        return try await recordExecution(
            intent: intent,
            id: id,
            record: .init(
                intentID: id,
                executionToolName: intent.executionToolName,
                status: .failed,
                summary: summary,
                startedAt: now,
                completedAt: now,
                result: result,
                errorMessage: normalized(
                    errorMessage
                ),
                metadata: metadata
            )
        )
    }

    public func delete(
        id: PreparedIntentIdentifier
    ) async throws {
        try await store.delete(
            id: id
        )
    }
}

private extension PreparedIntentManager {
    func recordExecution(
        intent: PreparedIntent,
        id: PreparedIntentIdentifier,
        record: PreparedIntentExecutionRecord
    ) async throws -> PreparedIntent {
        guard record.intentID == id else {
            throw PreparedIntentError.executionRecordIntentMismatch(
                expected: id,
                actual: record.intentID
            )
        }

        var intent = intent
        intent.status = record.status.resolvedIntentStatus
        intent.executionRecord = record

        try await store.save(
            intent
        )

        return intent
    }

    func normalized(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? nil : trimmed
    }

    func normalizedRequired(
        _ value: String,
        error: PreparedIntentError
    ) throws -> String {
        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            throw error
        }

        return trimmed
    }
}
