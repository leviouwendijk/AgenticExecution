import Foundation

public struct PreparedIntentDraft: Sendable, Codable, Hashable {
    public var sessionID: String?
    public var operation: PreparedOperation.Envelope
    public var reviewPayload: PreparedIntentReviewPayload
    public var expiresAt: Date?
    public var idempotencyKey: String?
    public var metadata: [String: String]

    public init(
        sessionID: String? = nil,
        operation: PreparedOperation.Envelope,
        reviewPayload: PreparedIntentReviewPayload,
        expiresAt: Date? = nil,
        idempotencyKey: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.sessionID = sessionID
        self.operation = operation
        self.reviewPayload = reviewPayload
        self.expiresAt = expiresAt
        self.idempotencyKey = idempotencyKey
        self.metadata = metadata
    }
}

