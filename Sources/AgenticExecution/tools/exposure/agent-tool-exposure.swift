import Agentic
import Foundation

public actor AgentToolExposure: ToolExposure {
    public let policy: AgentToolExposurePolicy

    private var activeIdentifiers:
        Set<ToolIdentifier>

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
    ) throws -> [ToolDescriptor] {
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
    ) throws -> [ToolIdentifier] {
        try definitions(
            in: registry
        ).map(
            \.identifier
        )
    }

    /// Inspect live exposure against immutable completed-registry metadata.
    /// Stale configured identifiers are ignored and results are deterministic.
    public func inspect(
        in registryInspection: AgentToolRegistryInspection
    ) -> AgentToolExposureInspection {
        let registered = Set(
            registryInspection.tools
                .filter(\.isModelFacing)
                .map(\.identifier)
        )

        let exposed: Set<ToolIdentifier>
        let seeded: Set<ToolIdentifier>
        let activated: Set<ToolIdentifier>

        switch policy {
        case .all:
            exposed = registered
            seeded = []
            activated = []

        case .explicit(let identifiers):
            seeded =
                Set(identifiers).intersection(registered)
            exposed =
                activeIdentifiers.intersection(registered)
            activated = []

        case .discoverable(let identifiers):
            seeded =
                Set(identifiers).intersection(registered)
            exposed =
                activeIdentifiers.intersection(registered)
            activated =
                exposed.subtracting(seeded)
        }

        let hidden =
            registered.subtracting(exposed)

        func ordered(
            _ identifiers: Set<ToolIdentifier>
        ) -> [ToolIdentifier] {
            identifiers.sorted {
                $0.rawValue < $1.rawValue
            }
        }

        return .init(
            policy: policy,
            registeredModelFacingCount: registered.count,
            exposedIdentifiers: ordered(exposed),
            hiddenIdentifiers: ordered(hidden),
            seededIdentifiers: ordered(seeded),
            activatedIdentifiers: ordered(activated)
        )
    }

    public func isExposed(
        _ identifier: ToolIdentifier,
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
        _ identifiers: [ToolIdentifier]
    ) async throws -> [ToolIdentifier] {
        try activateKnownIdentifiers(
            identifiers
        )
    }

    @discardableResult
    public func activate(
        _ identifiers: [ToolIdentifier],
        in registry: ToolRegistry
    ) throws -> [ToolIdentifier] {
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

            return try activateKnownIdentifiers(
                definitions.map(\.identifier)
            )
        }
    }

    private func activateKnownIdentifiers(
        _ identifiers: [ToolIdentifier]
    ) throws -> [ToolIdentifier] {
        switch policy {
        case .all:
            return []

        case .explicit:
            throw AgentToolExposureError
                .activationNotAllowed

        case .discoverable:
            var activated: [ToolIdentifier] = []

            for identifier in identifiers {
                if activeIdentifiers.insert(
                    identifier
                ).inserted {
                    activated.append(
                        identifier
                    )
                }
            }

            return activated
        }
    }

    public func parseModelCall(
        _ call: ToolCall,
        registry: ToolRegistry
    ) throws -> ParsedAgentToolCall {
        let identifier =
            ToolIdentifier(
                call.tool.rawValue
            )

        guard isExposed(
            identifier,
            in: registry
        ) else {
            throw AgentToolExposureError
                .toolNotExposed(
                    call.tool.rawValue
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
