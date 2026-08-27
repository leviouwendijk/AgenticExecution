import Foundation

public struct PreparedIntentDraft: Sendable, Codable, Hashable {
    public var sessionID: String?
    public var actionType: String
    public var reviewPayload: PreparedIntentReviewPayload
    public var executionToolName: String?
    public var idempotencyKey: String?
    public var metadata: [String: String]

    public init(
        sessionID: String? = nil,
        actionType: String,
        reviewPayload: PreparedIntentReviewPayload,
        executionToolName: String? = nil,
        idempotencyKey: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.sessionID = sessionID
        self.actionType = actionType
        self.reviewPayload = reviewPayload
        self.executionToolName = executionToolName
        self.idempotencyKey = idempotencyKey
        self.metadata = metadata
    }
}
