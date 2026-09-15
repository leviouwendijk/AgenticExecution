import AgenticExecution
import Foundation
import TestFlows
import Version

private struct PreparedOperationFixture:
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
        identifier: "fixture.prepared_operation",
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
            value: "executed:\(plan.value)",
            sessionID: context.sessionID
        )
    }
}

extension AgenticExecutionFlowTesting {
    static func runPreparedOperationEnvelope()
        async throws
        -> [TestFlowDiagnostic]
    {
        let source = PreparedOperationFixture.Plan(
            value: "durable-plan"
        )
        let envelope = try PreparedOperationFixture.envelope(
            source
        )

        try Expect.equal(
            envelope.schema.identifier,
            "fixture.prepared_operation",
            "prepared operation envelope retains strongly typed schema identity"
        )
        try Expect.equal(
            envelope.schema.version,
            ObjectVersion(
                major: 0,
                minor: 1,
                patch: 0
            ),
            "prepared operation schema exposes ObjectVersion through schema.version"
        )

        let persisted = try JSONDecoder().decode(
            PreparedOperation.Envelope.self,
            from: JSONEncoder().encode(
                envelope
            )
        )

        try Expect.equal(
            persisted,
            envelope,
            "prepared operation envelope survives durable Codable round trip"
        )

        let decoded = try PreparedOperationFixture.plan(
            from: persisted
        )

        try Expect.equal(
            decoded,
            source,
            "prepared operation restores the exact typed Plan from its durable envelope"
        )

        let result = try await PreparedOperationFixture().execute(
            decoded,
            context: .init(
                sessionID: "prepared-operation-fixture",
                metadata: [
                    "source": "test_flow",
                ]
            )
        )

        try Expect.equal(
            result,
            .init(
                value: "executed:durable-plan",
                sessionID: "prepared-operation-fixture"
            ),
            "prepared operation executes with typed Plan and typed Result"
        )

        let incompatible = PreparedOperation.Envelope(
            schema: .init(
                identifier: "fixture.other_operation",
                version: ObjectVersion(
                    major: 0,
                    minor: 1,
                    patch: 0
                )
            ),
            plan: envelope.plan
        )
        var schemaMismatchRejected = false

        do {
            _ = try PreparedOperationFixture.plan(
                from: incompatible
            )
        } catch PreparedOperation.EnvelopeError.schema_mismatch(
            let expected,
            let actual
        ) {
            schemaMismatchRejected = true

            try Expect.equal(
                expected,
                PreparedOperationFixture.schema,
                "schema mismatch carries the operation's expected schema"
            )
            try Expect.equal(
                actual,
                incompatible.schema,
                "schema mismatch carries the durable envelope's actual schema"
            )
        }

        try Expect.equal(
            schemaMismatchRejected,
            true,
            "a prepared operation refuses to decode an envelope authored for another schema"
        )

        return [
            .field(
                "schema",
                envelope.schema.identifier.rawValue
            ),
            .field(
                "version",
                envelope.schema.version.string(
                    prefixStyle: .none
                )
            ),
            .field(
                "typed_plan",
                decoded.value
            ),
            .field(
                "typed_result",
                result.value
            ),
        ]
    }
}
