import Agentic
import Foundation

public struct PreparedIntent: Sendable, Codable, Hashable, Identifiable {
    public let id: PreparedIntentIdentifier
    public var sessionID: String?
    public var operation: PreparedOperation.Envelope
    public var status: PreparedIntentStatus
    public var reviewPayload: PreparedIntentReviewPayload
    public var expiresAt: Date?
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
        operation: PreparedOperation.Envelope,
        status: PreparedIntentStatus = .pending_review,
        reviewPayload: PreparedIntentReviewPayload,
        expiresAt: Date? = nil,
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
        self.operation = operation
        self.status = status
        self.reviewPayload = reviewPayload
        self.expiresAt = expiresAt
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
        guard let expiresAt else {
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

    var executionResult: PreparedOperation.ResultEnvelope? {
        executionRecord?.result
    }
}

