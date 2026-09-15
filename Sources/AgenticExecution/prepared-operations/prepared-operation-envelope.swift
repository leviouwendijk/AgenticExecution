import Primitives

public extension PreparedOperation {
    struct Envelope:
        Sendable,
        Codable,
        Hashable
    {
        public let schema: Schema
        public let plan: JSONValue

        public init(
            schema: Schema,
            plan: JSONValue
        ) {
            self.schema = schema
            self.plan = plan
        }
    }

    enum EnvelopeError:
        Error,
        Sendable,
        Hashable
    {
        case schema_mismatch(
            expected: Schema,
            actual: Schema
        )
    }
}
