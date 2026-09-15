import Primitives

public protocol AgentPreparedOperation: Sendable {
    associatedtype Plan:
        Sendable &
        Codable &
        Hashable

    associatedtype Result:
        Sendable &
        Codable &
        Hashable

    static var schema: PreparedOperation.Schema { get }

    func execute(
        _ plan: Plan,
        context: PreparedOperation.Context
    ) async throws -> Result
}

public extension AgentPreparedOperation {
    static func envelope(
        _ plan: Plan
    ) throws -> PreparedOperation.Envelope {
        .init(
            schema: schema,
            plan: try JSONValueCodec.encodeValue(
                plan
            )
        )
    }

    static func plan(
        from envelope: PreparedOperation.Envelope
    ) throws -> Plan {
        guard envelope.schema == schema else {
            throw PreparedOperation.EnvelopeError.schema_mismatch(
                expected: schema,
                actual: envelope.schema
            )
        }

        return try envelope.plan.as(
            Plan.self
        )
    }
}
