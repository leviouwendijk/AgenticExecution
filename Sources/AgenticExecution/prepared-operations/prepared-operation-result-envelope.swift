import Primitives

public extension PreparedOperation {
    struct ResultEnvelope:
        Sendable,
        Codable,
        Hashable
    {
        public let schema: Schema
        public let result: JSONValue

        public init(
            schema: Schema,
            result: JSONValue
        ) {
            self.schema = schema
            self.result = result
        }
    }
}

public extension AgentPreparedOperation {
    static func resultEnvelope(
        _ result: Result
    ) throws -> PreparedOperation.ResultEnvelope {
        .init(
            schema: schema,
            result: try JSONValue.encoding(
                result
            )
        )
    }

    static func result(
        from envelope: PreparedOperation.ResultEnvelope
    ) throws -> Result {
        guard envelope.schema == schema else {
            throw PreparedOperation.EnvelopeError.schema_mismatch(
                expected: schema,
                actual: envelope.schema
            )
        }

        return try envelope.result.decode(
            Result.self
        )
    }
}
