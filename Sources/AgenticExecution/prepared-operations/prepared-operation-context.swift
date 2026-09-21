import Agentic
import Workspace

public extension PreparedOperation {
    struct Context: Sendable {
        public let workspace: WorkspaceContext?
        public let sessionID: String?
        public let preparedIntentID: PreparedIntentIdentifier?
        public let metadata: [String: String]

        public init(
            workspace: WorkspaceContext? = nil,
            sessionID: String? = nil,
            preparedIntentID: PreparedIntentIdentifier? = nil,
            metadata: [String: String] = [:]
        ) {
            self.workspace = workspace
            self.sessionID = sessionID
            self.preparedIntentID = preparedIntentID
            self.metadata = metadata
        }
    }
}

