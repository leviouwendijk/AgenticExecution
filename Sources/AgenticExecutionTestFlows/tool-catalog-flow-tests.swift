import Agentic
import AgenticExecution
import TestFlows
import Workspace

extension AgenticExecutionFlowTesting {
    static func runToolCatalog()
        async throws
        -> [TestDiagnostic]
    {
        let registrations = tools {
            collection(
                "core",
                title: "Core",
                defaultExposure: .included
            ) {
                ToolCatalogProbeTool<
                    CatalogCoreIdentity
                >()
            }

            collection(
                "media",
                title: "Media",
                defaultExposure: .excluded
            ) {
                ToolCatalogProbeTool<
                    CatalogMediaIdentity
                >()
            }

            ToolCatalogProbeTool<
                CatalogLegacyIdentity
            >()
        }

        let registry = try Agentic.tool.registry {
            registrations
        }
        let catalog = try AgentToolCatalog.materialize(
            registrations: registrations,
            registry: registry
        )

        try Expect.equal(
            catalog.collections.map(
                \.identifier
            ),
            [
                AgentToolCollectionIdentifier(
                    rawValue: "core"
                ),
                AgentToolCollectionIdentifier(
                    rawValue: "media"
                ),
                AgentToolCollectionMetadata
                    .ungrouped
                    .identifier,
                AgentToolCollectionMetadata
                    .intrinsics
                    .identifier,
            ],
            "catalog preserves declared collection order and appends intrinsic capabilities"
        )

        let core = try Expect.notNil(
            catalog.collection(
                identifiedBy: .init(
                    rawValue: "core"
                )
            ),
            "catalog contains the Core collection"
        )
        let media = try Expect.notNil(
            catalog.collection(
                identifiedBy: .init(
                    rawValue: "media"
                )
            ),
            "catalog contains the Media collection"
        )
        let application = try Expect.notNil(
            catalog.collection(
                identifiedBy:
                    AgentToolCollectionMetadata
                        .ungrouped
                        .identifier
            ),
            "catalog retains ungrouped application registrations"
        )
        let intrinsics = try Expect.notNil(
            catalog.collection(
                identifiedBy:
                    AgentToolCollectionMetadata
                        .intrinsics
                        .identifier
            ),
            "catalog classifies registry-owned intrinsic tools"
        )

        try Expect.equal(
            core.defaultExposure,
            .included,
            "Core is default exposed"
        )
        try Expect.equal(
            core.toolIdentifiers,
            [
                ToolIdentifier(
                    "catalog_core"
                ),
            ],
            "Core resolves to exact registered tool identifiers"
        )
        try Expect.equal(
            media.defaultExposure,
            .excluded,
            "Media is registered but default excluded"
        )
        try Expect.equal(
            media.toolIdentifiers,
            [
                ToolIdentifier(
                    "catalog_media"
                ),
            ],
            "Media remains catalogued while default excluded"
        )
        try Expect.equal(
            application.toolIdentifiers,
            [
                ToolIdentifier(
                    "catalog_legacy"
                ),
            ],
            "legacy ungrouped declarations remain supported"
        )
        try Expect.equal(
            intrinsics.defaultExposure,
            .excluded,
            "intrinsic tools are catalogued without silently entering default exposure"
        )
        try Expect.equal(
            intrinsics.toolIdentifiers,
            [
                InspectToolRegistryTool.identifier,
            ],
            "canonical registry additions become intrinsic catalog entries"
        )

        let intrinsicEntry = try Expect.notNil(
            catalog.entry(
                identifiedBy:
                    InspectToolRegistryTool.identifier
            ),
            "intrinsic catalog entry is addressable by exact tool identifier"
        )

        try Expect.equal(
            intrinsicEntry.origin,
            .intrinsic,
            "catalog records intrinsic provenance"
        )
        try Expect.equal(
            catalog.defaultExposedIdentifiers,
            [
                ToolIdentifier(
                    "catalog_core"
                ),
                ToolIdentifier(
                    "catalog_legacy"
                ),
            ],
            "default exposure contains only model-facing tools from included collections"
        )

        try proveConflictingToolCollectionMetadataFails()

        return [
            .field(
                "collections",
                "\(catalog.collections.count)"
            ),
            .field(
                "entries",
                "\(catalog.entries.count)"
            ),
            .field(
                "default_exposed",
                "\(catalog.defaultExposedIdentifiers.count)"
            ),
        ]
    }
}

private func proveConflictingToolCollectionMetadataFails()
    throws
{
    let registrations = tools {
        collection(
            "shared",
            title: "First"
        ) {
            ToolCatalogProbeTool<
                CatalogConflictAIdentity
            >()
        }

        collection(
            "shared",
            title: "Second"
        ) {
            ToolCatalogProbeTool<
                CatalogConflictBIdentity
            >()
        }
    }

    let registry = try Agentic.tool.registry {
        registrations
    }

    do {
        _ = try AgentToolCatalog.materialize(
            registrations: registrations,
            registry: registry
        )

        throw ToolCatalogFlowError
            .expectedConflictingCollectionMetadata
    } catch AgentToolCatalogError
        .conflictingCollectionMetadata(let identifier)
    {
        try Expect.equal(
            identifier,
            AgentToolCollectionIdentifier(
                rawValue: "shared"
            ),
            "reusing one collection identifier with conflicting metadata is rejected deterministically"
        )
    }
}

private protocol ToolCatalogProbeIdentity {
    static var identifier: ToolIdentifier { get }
}

private enum CatalogCoreIdentity: ToolCatalogProbeIdentity {
    static let identifier:
        ToolIdentifier = "catalog_core"
}

private enum CatalogMediaIdentity: ToolCatalogProbeIdentity {
    static let identifier:
        ToolIdentifier = "catalog_media"
}

private enum CatalogLegacyIdentity: ToolCatalogProbeIdentity {
    static let identifier:
        ToolIdentifier = "catalog_legacy"
}

private enum CatalogConflictAIdentity: ToolCatalogProbeIdentity {
    static let identifier:
        ToolIdentifier = "catalog_conflict_a"
}

private enum CatalogConflictBIdentity: ToolCatalogProbeIdentity {
    static let identifier:
        ToolIdentifier = "catalog_conflict_b"
}

private struct ToolCatalogProbeTool<
    Identity: ToolCatalogProbeIdentity
>: Tool {
    typealias Input = InspectToolRegistryToolInput
    typealias Output = InspectToolRegistryToolInput

    static var definition: ToolDefinition {
        .init(
            identifier: Identity.identifier,
            purpose:
                "Catalog probe for \(Identity.identifier.rawValue).",
            risk: .observe
        )
    }

    func call(
        _ input: Input,
        workspace _: WorkspaceContext?
    ) async throws -> Output {
        input
    }
}

private enum ToolCatalogFlowError:
    Error
{
    case expectedConflictingCollectionMetadata
}
