import Agentic
import Foundation

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
    public let operation: PreparedOperation.Schema
    public let status: PreparedIntentExecutionStatus
    public let summary: String
    public let startedAt: Date
    public let completedAt: Date
    public let result: PreparedOperation.ResultEnvelope?
    public let errorMessage: String?
    public let metadata: [String: String]

    public init(
        id: String = UUID().uuidString,
        intentID: PreparedIntentIdentifier,
        operation: PreparedOperation.Schema,
        status: PreparedIntentExecutionStatus,
        summary: String,
        startedAt: Date = Date(),
        completedAt: Date = Date(),
        result: PreparedOperation.ResultEnvelope? = nil,
        errorMessage: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.intentID = intentID
        self.operation = operation
        self.status = status
        self.summary = summary
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.result = result
        self.errorMessage = errorMessage
        self.metadata = metadata
    }
}
