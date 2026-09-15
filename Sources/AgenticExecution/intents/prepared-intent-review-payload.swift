import Agentic

public struct PreparedIntentReviewPayload: Sendable, Codable, Hashable {
    public var title: String
    public var summary: String
    public var risk: ActionRisk
    public var target: String?
    public var expectedSideEffects: [String]
    public var policyChecks: [String]
    public var warnings: [String]
    public var metadata: [String: String]

    public init(
        title: String,
        summary: String,
        risk: ActionRisk,
        target: String? = nil,
        expectedSideEffects: [String] = [],
        policyChecks: [String] = [],
        warnings: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.title = title
        self.summary = summary
        self.risk = risk
        self.target = target
        self.expectedSideEffects = expectedSideEffects
        self.policyChecks = policyChecks
        self.warnings = warnings
        self.metadata = metadata
    }
}

