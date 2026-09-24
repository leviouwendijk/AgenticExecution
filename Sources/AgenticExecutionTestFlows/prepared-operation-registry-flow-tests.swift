import AgenticExecution
import TestFlows
import Version

private struct PreparedOperationRegistryFixture:
    AgentPreparedOperation
{
    struct Plan:
        Sendable,
        Codable,
        Hashable
    {
        let value: String
    }

    struct Result:
        Sendable,
        Codable,
        Hashable
    {
        let value: String
        let sessionID: String?
    }

    static let schema = PreparedOperation.Schema(
        identifier: "fixture.prepared_operation_registry",
        version: ObjectVersion(
            major: 0,
            minor: 1,
            patch: 0
        )
    )

    func execute(
        _ plan: Plan,
        context: PreparedOperation.Context
    ) async throws -> Result {
        .init(
            value: "registry:\(plan.value)",
            sessionID: context.sessionID
        )
    }
}

extension AgenticExecutionFlowTesting {
    static func runPreparedOperationRegistry()
        async throws
        -> [TestDiagnostic]
    {
        let operation = PreparedOperationRegistryFixture()
        var registry = PreparedOperationRegistry()

        try registry.register(
            operation
        )

        try Expect.equal(
            registry.count,
            1,
            "prepared operation registry stores one exact schema registration"
        )
        try Expect.equal(
            registry.schemas,
            [
                PreparedOperationRegistryFixture.schema,
            ],
            "prepared operation registry surfaces exact registered schemas"
        )

        let plan = PreparedOperationRegistryFixture.Plan(
            value: "typed-plan"
        )
        let envelope = try PreparedOperationRegistryFixture.envelope(
            plan
        )
        let resultEnvelope = try await registry.execute(
            envelope,
            context: .init(
                sessionID: "prepared-operation-registry-fixture"
            )
        )

        try Expect.equal(
            resultEnvelope.schema,
            envelope.schema,
            "prepared operation result envelope retains the exact operation schema"
        )

        let result = try PreparedOperationRegistryFixture.result(
            from: resultEnvelope
        )

        try Expect.equal(
            result,
            .init(
                value: "registry:typed-plan",
                sessionID: "prepared-operation-registry-fixture"
            ),
            "registry execution restores typed Plan and typed Result across erased boundaries"
        )

        var duplicateRejected = false

        do {
            try registry.register(
                operation
            )
        } catch PreparedOperationRegistryError.duplicateSchema(
            let schema
        ) {
            duplicateRejected = true

            try Expect.equal(
                schema,
                PreparedOperationRegistryFixture.schema,
                "duplicate registration reports the exact colliding schema"
            )
        }

        try Expect.equal(
            duplicateRejected,
            true,
            "prepared operation registry rejects duplicate exact schema registration"
        )

        let futureSchema = PreparedOperation.Schema(
            identifier: PreparedOperationRegistryFixture
                .schema
                .identifier,
            version: ObjectVersion(
                major: 0,
                minor: 2,
                patch: 0
            )
        )
        let futureEnvelope = PreparedOperation.Envelope(
            schema: futureSchema,
            plan: envelope.plan
        )
        var futureVersionRejected = false

        do {
            _ = try await registry.execute(
                futureEnvelope
            )
        } catch PreparedOperationRegistryError.unregisteredSchema(
            let schema
        ) {
            futureVersionRejected = true

            try Expect.equal(
                schema,
                futureSchema,
                "unregistered execution reports the exact versioned schema"
            )
        }

        try Expect.equal(
            futureVersionRejected,
            true,
            "registry never executes an unregistered future schema version through an older implementation"
        )

        return [
            .field(
                "registered",
                String(registry.count)
            ),
            .field(
                "schema",
                resultEnvelope.schema.identifier.rawValue
            ),
            .field(
                "version",
                resultEnvelope.schema.version.string(
                    prefixStyle: .none
                )
            ),
            .field(
                "typed_result",
                result.value
            ),
            .field(
                "future_version_rejected",
                String(futureVersionRejected)
            ),
        ]
    }
}
