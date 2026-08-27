import Agentic
import Foundation
import Primitives

public struct PreparedIntent: Sendable, Codable, Hashable, Identifiable {
    public let id: PreparedIntentIdentifier
    public var sessionID: String?
    public var actionType: String
    public var status: PreparedIntentStatus
    public var reviewPayload: PreparedIntentReviewPayload
    public var executionToolName: String?
    public var idempotencyKey: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var reviewedAt: Date?
    public var reviewedBy: String?
    public var reviewNote: String?
    public var executionRecord: PreparedIntentExecutionRecord?
    public var metadata: [String: String]

    public init(
        id: PreparedIntentIdentifier = .init(UUID().uuidString),
        sessionID: String? = nil,
        actionType: String,
        status: PreparedIntentStatus = .pending_review,
        reviewPayload: PreparedIntentReviewPayload,
        executionToolName: String? = nil,
        idempotencyKey: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        reviewedAt: Date? = nil,
        reviewedBy: String? = nil,
        reviewNote: String? = nil,
        executionRecord: PreparedIntentExecutionRecord? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.sessionID = sessionID
        self.actionType = actionType
        self.status = status
        self.reviewPayload = reviewPayload
        self.executionToolName = executionToolName
        self.idempotencyKey = idempotencyKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.reviewedAt = reviewedAt
        self.reviewedBy = reviewedBy
        self.reviewNote = reviewNote
        self.executionRecord = executionRecord
        self.metadata = metadata
    }
}

public extension PreparedIntent {
    func isExpired(
        at date: Date = Date()
    ) -> Bool {
        guard let expiresAt = reviewPayload.expiresAt else {
            return false
        }

        return expiresAt <= date
    }

    var canBeExecuted: Bool {
        status.canBeExecuted && !isExpired()
    }

    var executedAt: Date? {
        executionRecord?.completedAt
    }

    var executionResult: JSONValue? {
        executionRecord?.result
    }
}
