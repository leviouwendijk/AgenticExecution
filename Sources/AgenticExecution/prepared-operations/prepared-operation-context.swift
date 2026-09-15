import Agentic
import AgenticWorkspace

public extension PreparedOperation {
    struct Context: Sendable {
        public let workspace: AgentWorkspace?
        public let workspaceLocation: WorkspaceLocation?
        public let sessionID: String?
        public let preparedIntentID: PreparedIntentIdentifier?
        public let metadata: [String: String]

        public init(
            workspace: AgentWorkspace? = nil,
            workspaceLocation: WorkspaceLocation? = nil,
            sessionID: String? = nil,
            preparedIntentID: PreparedIntentIdentifier? = nil,
            metadata: [String: String] = [:]
        ) {
            self.workspace = workspace
            self.workspaceLocation = workspaceLocation
            self.sessionID = sessionID
            self.preparedIntentID = preparedIntentID
            self.metadata = metadata
        }
    }
}
