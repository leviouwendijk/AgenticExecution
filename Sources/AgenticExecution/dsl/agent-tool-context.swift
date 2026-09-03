import Agentic
import AgenticWorkspace
import Foundation

public enum AgentToolExecutionMode: String, Sendable, Codable, Hashable, CaseIterable {
    case model_tool_call
    case prepared_intent_replay
    case host_call
}

public struct AgentToolObservationSink: Sendable {
    private let handler:
        @Sendable (AgentToolResultObservation) async -> Void

    public init(
        _ handler:
            @escaping @Sendable (AgentToolResultObservation) async -> Void
    ) {
        self.handler = handler
    }

    public func observe(
        _ observation: AgentToolResultObservation
    ) async {
        await handler(
            observation
        )
    }
}

public struct AgentToolExecutionContext: Sendable {
    public let workspace: AgentWorkspace?
    public let workspaceLocation: WorkspaceLocation?
    public let sessionID: String?
    public let toolCallID: String?
    public let preparedIntentID: PreparedIntentIdentifier?
    public let executionMode: AgentToolExecutionMode
    public let guidelineRelations: [AgentGuidelineRelation]
    public let metadata: [String: String]
    public let observationSink: AgentToolObservationSink?

    public init(
        workspace: AgentWorkspace? = nil,
        workspaceLocation: WorkspaceLocation? = nil,
        sessionID: String? = nil,
        toolCallID: String? = nil,
        preparedIntentID: PreparedIntentIdentifier? = nil,
        executionMode: AgentToolExecutionMode = .host_call,
        guidelineRelations: [AgentGuidelineRelation] = [],
        metadata: [String: String] = [:],
        observationSink: AgentToolObservationSink? = nil
    ) {
        self.workspace = workspace
        self.workspaceLocation = workspaceLocation
        self.sessionID = sessionID
        self.toolCallID = toolCallID
        self.preparedIntentID = preparedIntentID
        self.executionMode = executionMode
        self.guidelineRelations = guidelineRelations
        self.metadata = metadata
        self.observationSink = observationSink
    }

    public var workingDirectoryURL: URL? {
        workspaceLocation?.absoluteURL
            ?? workspace?.rootURL
    }

    public func observe(
        _ observation: AgentToolResultObservation
    ) async {
        await observationSink?.observe(
            observation
        )
    }

    public func withObservationSink(
        _ observationSink: AgentToolObservationSink?
    ) -> Self {
        .init(
            workspace: workspace,
            workspaceLocation: workspaceLocation,
            sessionID: sessionID,
            toolCallID: toolCallID,
            preparedIntentID: preparedIntentID,
            executionMode: executionMode,
            guidelineRelations: guidelineRelations,
            metadata: metadata,
            observationSink: observationSink
        )
    }

    public func withWorkspaceLocation(
        _ workspaceLocation: WorkspaceLocation?
    ) -> Self {
        .init(
            workspace: workspace,
            workspaceLocation: workspaceLocation,
            sessionID: sessionID,
            toolCallID: toolCallID,
            preparedIntentID: preparedIntentID,
            executionMode: executionMode,
            guidelineRelations: guidelineRelations,
            metadata: metadata,
            observationSink: observationSink
        )
    }

    public func withToolCallID(
        _ toolCallID: String?
    ) -> Self {
        .init(
            workspace: workspace,
            workspaceLocation: workspaceLocation,
            sessionID: sessionID,
            toolCallID: toolCallID,
            preparedIntentID: preparedIntentID,
            executionMode: executionMode,
            guidelineRelations: guidelineRelations,
            metadata: metadata,
            observationSink: observationSink
        )
    }

    public func withPreparedIntentID(
        _ preparedIntentID: PreparedIntentIdentifier?
    ) -> Self {
        .init(
            workspace: workspace,
            workspaceLocation: workspaceLocation,
            sessionID: sessionID,
            toolCallID: toolCallID,
            preparedIntentID: preparedIntentID,
            executionMode: executionMode,
            guidelineRelations: guidelineRelations,
            metadata: metadata,
            observationSink: observationSink
        )
    }

    public func withExecutionMode(
        _ executionMode: AgentToolExecutionMode
    ) -> Self {
        .init(
            workspace: workspace,
            workspaceLocation: workspaceLocation,
            sessionID: sessionID,
            toolCallID: toolCallID,
            preparedIntentID: preparedIntentID,
            executionMode: executionMode,
            guidelineRelations: guidelineRelations,
            metadata: metadata,
            observationSink: observationSink
        )
    }

    public func appendingGuidelineRelations(
        _ additionalRelations: [AgentGuidelineRelation]
    ) -> Self {
        var guidelineRelations = guidelineRelations

        for relation in additionalRelations
        where !guidelineRelations.contains(relation)
        {
            guidelineRelations.append(
                relation
            )
        }

        return .init(
            workspace: workspace,
            workspaceLocation: workspaceLocation,
            sessionID: sessionID,
            toolCallID: toolCallID,
            preparedIntentID: preparedIntentID,
            executionMode: executionMode,
            guidelineRelations: guidelineRelations,
            metadata: metadata,
            observationSink: observationSink
        )
    }

    public func mergingMetadata(
        _ additionalMetadata: [String: String]
    ) -> Self {
        .init(
            workspace: workspace,
            workspaceLocation: workspaceLocation,
            sessionID: sessionID,
            toolCallID: toolCallID,
            preparedIntentID: preparedIntentID,
            executionMode: executionMode,
            guidelineRelations: guidelineRelations,
            metadata: metadata.merging(
                additionalMetadata
            ) { _, new in
                new
            },
            observationSink: observationSink
        )
    }
}

public typealias AgentToolContext = AgentToolExecutionContext
