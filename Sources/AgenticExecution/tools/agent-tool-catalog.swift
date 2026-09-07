import Agentic

public enum AgentToolOrigin:
    String,
    Sendable,
    Codable,
    Hashable
{
    case declared
    case intrinsic
}

public struct AgentToolCatalogEntry:
    Sendable
{
    public let identifier: AgentToolIdentifier
    public let title: String
    public let description: String
    public let risk: ActionRisk
    public let isModelFacing: Bool
    public let workingLocation:
        AgentToolExecutionContract.WorkingLocation
    public let origin: AgentToolOrigin
    public let collectionIdentifier:
        AgentToolCollectionIdentifier
    public let defaultExposure: AgentToolDefaultExposure

    public init(
        identifier: AgentToolIdentifier,
        title: String,
        description: String,
        risk: ActionRisk,
        isModelFacing: Bool,
        workingLocation:
            AgentToolExecutionContract.WorkingLocation,
        origin: AgentToolOrigin,
        collectionIdentifier:
            AgentToolCollectionIdentifier,
        defaultExposure: AgentToolDefaultExposure
    ) {
        self.identifier = identifier
        self.title = title
        self.description = description
        self.risk = risk
        self.isModelFacing = isModelFacing
        self.workingLocation = workingLocation
        self.origin = origin
        self.collectionIdentifier = collectionIdentifier
        self.defaultExposure = defaultExposure
    }
}

public struct AgentToolCollection:
    Sendable
{
    public let identifier: AgentToolCollectionIdentifier
    public let title: String
    public let defaultExposure: AgentToolDefaultExposure
    public let toolIdentifiers: [AgentToolIdentifier]

    public init(
        identifier: AgentToolCollectionIdentifier,
        title: String,
        defaultExposure: AgentToolDefaultExposure,
        toolIdentifiers: [AgentToolIdentifier]
    ) {
        self.identifier = identifier
        self.title = title
        self.defaultExposure = defaultExposure
        self.toolIdentifiers = toolIdentifiers
    }
}

public enum AgentToolCatalogError:
    Error,
    Sendable
{
    case conflictingCollectionMetadata(
        AgentToolCollectionIdentifier
    )
    case toolAssignedToMultipleCollections(
        AgentToolIdentifier
    )
    case registeredToolMissingFromCompletedRegistry(
        AgentToolIdentifier
    )
}

public struct AgentToolCatalog:
    Sendable
{
    public let collections: [AgentToolCollection]
    public let entries: [AgentToolCatalogEntry]

    public init(
        collections: [AgentToolCollection],
        entries: [AgentToolCatalogEntry]
    ) {
        self.collections = collections
        self.entries = entries
    }

    public var modelFacingEntries: [AgentToolCatalogEntry] {
        entries.filter(
            \.isModelFacing
        )
    }

    public var defaultExposedIdentifiers:
        [AgentToolIdentifier]
    {
        entries.compactMap { entry in
            guard entry.isModelFacing,
                entry.defaultExposure == .included
            else {
                return nil
            }

            return entry.identifier
        }
    }

    public func collection(
        identifiedBy identifier: AgentToolCollectionIdentifier
    ) -> AgentToolCollection? {
        collections.first { collection in
            collection.identifier == identifier
        }
    }

    public func entry(
        identifiedBy identifier: AgentToolIdentifier
    ) -> AgentToolCatalogEntry? {
        entries.first { entry in
            entry.identifier == identifier
        }
    }

    public static func materialize(
        registrations: [AgentToolRegistration],
        registry: ToolRegistry
    ) throws -> Self {
        var metadataByIdentifier:
            [AgentToolCollectionIdentifier: AgentToolCollectionMetadata] = [:]
        var registrationGroups:
            [AgentToolCollectionIdentifier: [AgentToolRegistration]] = [:]
        var collectionOrder:
            [AgentToolCollectionIdentifier] = []

        for registration in registrations {
            let metadata = registration.collection
                ?? .ungrouped
            let identifier = metadata.identifier

            if let existing = metadataByIdentifier[identifier] {
                guard existing == metadata else {
                    throw AgentToolCatalogError
                        .conflictingCollectionMetadata(
                            identifier
                        )
                }
            } else {
                metadataByIdentifier[identifier] = metadata
                collectionOrder.append(
                    identifier
                )
            }

            registrationGroups[identifier, default: []]
                .append(
                    registration
                )
        }

        let completedInspection = registry.inspect()
        let completedByIdentifier = Dictionary(
            uniqueKeysWithValues:
                completedInspection.tools.map { entry in
                    (
                        entry.identifier,
                        entry
                    )
                }
        )

        var claimedIdentifiers:
            Set<AgentToolIdentifier> = []
        var collections: [AgentToolCollection] = []
        var entries: [AgentToolCatalogEntry] = []

        for collectionIdentifier in collectionOrder {
            guard let metadata =
                metadataByIdentifier[collectionIdentifier]
            else {
                continue
            }

            var isolatedRegistry = ToolRegistry()

            for registration in
                registrationGroups[collectionIdentifier] ?? []
            {
                try registration.apply(
                    into: &isolatedRegistry
                )
            }

            let toolIdentifiers = isolatedRegistry
                .inspect()
                .tools
                .map(
                    \.identifier
                )

            for toolIdentifier in toolIdentifiers {
                guard claimedIdentifiers.insert(
                    toolIdentifier
                ).inserted else {
                    throw AgentToolCatalogError
                        .toolAssignedToMultipleCollections(
                            toolIdentifier
                        )
                }

                guard let inspection =
                    completedByIdentifier[toolIdentifier]
                else {
                    throw AgentToolCatalogError
                        .registeredToolMissingFromCompletedRegistry(
                            toolIdentifier
                        )
                }

                entries.append(
                    catalogEntry(
                        inspection: inspection,
                        origin: .declared,
                        collection: metadata
                    )
                )
            }

            collections.append(
                .init(
                    identifier: metadata.identifier,
                    title: metadata.title,
                    defaultExposure:
                        metadata.defaultExposure,
                    toolIdentifiers: toolIdentifiers
                )
            )
        }

        let intrinsicMetadata =
            AgentToolCollectionMetadata.intrinsics
        let intrinsicInspections = completedInspection.tools
            .filter { inspection in
                !claimedIdentifiers.contains(
                    inspection.identifier
                )
            }

        if !intrinsicInspections.isEmpty {
            let intrinsicIdentifiers = intrinsicInspections.map(
                \.identifier
            )

            collections.append(
                .init(
                    identifier: intrinsicMetadata.identifier,
                    title: intrinsicMetadata.title,
                    defaultExposure:
                        intrinsicMetadata.defaultExposure,
                    toolIdentifiers: intrinsicIdentifiers
                )
            )

            entries.append(
                contentsOf: intrinsicInspections.map { inspection in
                    catalogEntry(
                        inspection: inspection,
                        origin: .intrinsic,
                        collection: intrinsicMetadata
                    )
                }
            )
        }

        return .init(
            collections: collections,
            entries: entries
        )
    }

    private static func catalogEntry(
        inspection: AgentToolRegistryInspectionEntry,
        origin: AgentToolOrigin,
        collection: AgentToolCollectionMetadata
    ) -> AgentToolCatalogEntry {
        .init(
            identifier: inspection.identifier,
            title: inspection.identifier.rawValue,
            description: inspection.description,
            risk: inspection.risk,
            isModelFacing: inspection.isModelFacing,
            workingLocation: inspection.workingLocation,
            origin: origin,
            collectionIdentifier: collection.identifier,
            defaultExposure: collection.defaultExposure
        )
    }
}
