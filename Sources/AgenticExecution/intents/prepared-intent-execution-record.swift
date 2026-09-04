import Agentic
import Foundation
import Primitives

public enum PreparedIntentExecutionStatus: String, Sendable, Codable, Hashable, CaseIterable {
    case succeeded
    case failed
}

public extension PreparedIntentExecutionStatus {
    var resolvedIntentStatus: PreparedIntentStatus {
        switch self {
        case .succeeded:
            return .executed

        case .failed:
            return .execution_failed
        }
    }
}

public struct PreparedIntentExecutionRecord: Sendable, Codable, Hashable, Identifiable {
    public let id: String
    public let intentID: PreparedIntentIdentifier
    public let executionToolName: String?
    public let status: PreparedIntentExecutionStatus
    public let summary: String
    public let startedAt: Date
    public let completedAt: Date
    public let result: JSONValue?
    public let toolFailure: AgentToolCallFailure?
    public let errorMessage: String?
    public let metadata: [String: String]

    public init(
        id: String = UUID().uuidString,
        intentID: PreparedIntentIdentifier,
        executionToolName: String? = nil,
        status: PreparedIntentExecutionStatus,
        summary: String,
        startedAt: Date = Date(),
        completedAt: Date = Date(),
        result: JSONValue? = nil,
        toolFailure: AgentToolCallFailure? = nil,
        errorMessage: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.intentID = intentID
        self.executionToolName = executionToolName
        self.status = status
        self.summary = summary
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.result = result
        self.toolFailure = toolFailure
        self.errorMessage = errorMessage
        self.metadata = metadata
    }
}