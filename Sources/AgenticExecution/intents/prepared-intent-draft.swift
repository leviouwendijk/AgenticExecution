import Foundation

public struct PreparedIntentDraft: Sendable, Codable, Hashable {
    public var sessionID: String?
    public var invocation: ToolInvocation.Prepared
    public var expiresAt: Date?
    public var idempotencyKey: String?
    public var metadata: [String: String]

    public init(
        sessionID: String? = nil,
        invocation: ToolInvocation.Prepared,
        expiresAt: Date? = nil,
        idempotencyKey: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.sessionID = sessionID
        self.invocation = invocation
        self.expiresAt = expiresAt
        self.idempotencyKey = idempotencyKey
        self.metadata = metadata
    }
}
