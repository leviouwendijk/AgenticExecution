import Agentic
import Foundation
import Primitives

public struct PreparedIntentReviewPayload: Sendable, Codable, Hashable {
    public var title: String
    public var summary: String
    public var actionType: String
    public var risk: ActionRisk
    public var target: String?
    public var exactInputs: JSONValue?
    public var expectedSideEffects: [String]
    public var policyChecks: [String]
    public var warnings: [String]
    public var expiresAt: Date?
    public var metadata: [String: String]

    public init(
        title: String,
        summary: String,
        actionType: String,
        risk: ActionRisk,
        target: String? = nil,
        exactInputs: JSONValue? = nil,
        expectedSideEffects: [String] = [],
        policyChecks: [String] = [],
        warnings: [String] = [],
        expiresAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.title = title
        self.summary = summary
        self.actionType = actionType
        self.risk = risk
        self.target = target
        self.exactInputs = exactInputs
        self.expectedSideEffects = expectedSideEffects
        self.policyChecks = policyChecks
        self.warnings = warnings
        self.expiresAt = expiresAt
        self.metadata = metadata
    }
}
