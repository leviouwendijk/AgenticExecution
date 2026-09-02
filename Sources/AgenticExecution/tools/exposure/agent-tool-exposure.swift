import Agentic
import Foundation

public actor AgentToolExposure {
    public let policy: AgentToolExposurePolicy

    private var activeIdentifiers:
        Set<AgentToolIdentifier>

    public init(
        policy: AgentToolExposurePolicy = .all
    ) {
        self.policy = policy

        switch policy {
        case .all:
            self.activeIdentifiers = []

        case .explicit(let identifiers),
             .discoverable(let identifiers):
            self.activeIdentifiers = Set(
                identifiers
            )
        }
    }

    public func definitions(
        in registry: ToolRegistry
    ) throws -> [AgentToolDefinition] {
        switch policy {
        case .all:
            registry.modelFacingDefinitions

        case .explicit,
             .discoverable:
            try registry.modelFacingDefinitions(
                for: Array(activeIdentifiers)
            )
        }
    }

    public func identifiers(
        in registry: ToolRegistry
    ) throws -> [AgentToolIdentifier] {
        try definitions(
            in: registry
        ).map(
            \.identifier
        )
    }

    public func isExposed(
        _ identifier: AgentToolIdentifier,
        in registry: ToolRegistry
    ) -> Bool {
        guard registry.modelFacingDefinition(
            identifiedBy: identifier
        ) != nil else {
            return false
        }

        switch policy {
        case .all:
            return true

        case .explicit,
             .discoverable:
            return activeIdentifiers.contains(
                identifier
            )
        }
    }

    @discardableResult
    public func activate(
        _ identifiers: [AgentToolIdentifier],
        in registry: ToolRegistry
    ) throws -> [AgentToolIdentifier] {
        switch policy {
        case .all:
            return []

        case .explicit:
            throw AgentToolExposureError
                .activationNotAllowed

        case .discoverable:
            let definitions =
                try registry.modelFacingDefinitions(
                    for: identifiers
                )

            var activated:
                [AgentToolIdentifier] = []

            for definition in definitions {
                if activeIdentifiers.insert(
                    definition.identifier
                ).inserted {
                    activated.append(
                        definition.identifier
                    )
                }
            }

            return activated
        }
    }

    public func parseModelCall(
        _ call: AgentToolCall,
        registry: ToolRegistry
    ) throws -> ParsedAgentToolCall {
        let identifier =
            AgentToolIdentifier(
                call.name
            )

        guard isExposed(
            identifier,
            in: registry
        ) else {
            throw AgentToolExposureError
                .toolNotExposed(
                    call.name
                )
        }

        return try registry.parseModelCall(
            call
        )
    }
}

public enum AgentToolExposureError:
    Error,
    Sendable,
    LocalizedError
{
    case activationNotAllowed
    case toolNotExposed(
        String
    )

    public var errorDescription: String? {
        switch self {
        case .activationNotAllowed:
            "This tool exposure policy does not allow dynamic activation."

        case .toolNotExposed(let tool):
            "Tool '\(tool)' is registered but is not exposed to the current model invocation."
        }
    }
}
