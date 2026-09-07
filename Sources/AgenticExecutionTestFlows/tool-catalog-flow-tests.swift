import Agentic
import AgenticExecution
import TestFlows

extension AgenticExecutionFlowTesting {
    static func runToolCatalog()
        async throws
        -> [TestFlowDiagnostic]
    {
        let registrations = tools {
            collection(
                "core",
                title: "Core",
                defaultExposure: .included
            ) {
                ToolCatalogProbeTool(
                    identifier: "catalog_core"
                )
            }

            collection(
                "media",
                title: "Media",
                defaultExposure: .excluded
            ) {
                ToolCatalogProbeTool(
                    identifier: "catalog_media"
                )
            }

            ToolCatalogProbeTool(
                identifier: "catalog_legacy"
            )
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
                AgentToolIdentifier(
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
                AgentToolIdentifier(
                    "catalog_media"
                ),
            ],
            "Media remains catalogued while default excluded"
        )
        try Expect.equal(
            application.toolIdentifiers,
            [
                AgentToolIdentifier(
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
                AgentToolIdentifier(
                    "catalog_core"
                ),
                AgentToolIdentifier(
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
            ToolCatalogProbeTool(
                identifier: "catalog_conflict_a"
            )
        }

        collection(
            "shared",
            title: "Second"
        ) {
            ToolCatalogProbeTool(
                identifier: "catalog_conflict_b"
            )
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

private struct ToolCatalogProbeTool:
    AgentTool
{
    typealias Input = InspectToolRegistryToolInput
    typealias Output = InspectToolRegistryToolInput

    let identifier: AgentToolIdentifier
    let description: String
    let risk: ActionRisk = .observe

    init(
        identifier: AgentToolIdentifier
    ) {
        self.identifier = identifier
        self.description =
            "Catalog probe for \(identifier.rawValue)."
    }

    func call(
        _ input: Input,
        context _: AgentToolExecutionContext
    ) async throws -> Output {
        input
    }
}

private enum ToolCatalogFlowError:
    Error
{
    case expectedConflictingCollectionMetadata
}
