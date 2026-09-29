import Macros
import Primitives
import Schema
import Version

public enum PreparedOperation {}

public extension PreparedOperation {
    struct Identifier:
        StringIdentifier,
        JSONSchemaProviding
    {
        public let rawValue: String

        public init(
            rawValue: String
        ) {
            self.rawValue = rawValue
        }

        public static var jsonschema: JSONSchema {
            .string()
        }
    }

    @JSONSchema
    struct Schema:
        Sendable,
        Codable,
        Hashable
    {
        public let identifier: Identifier
        public let version: ObjectVersion

        public init(
            identifier: Identifier,
            version: ObjectVersion
        ) {
            self.identifier = identifier
            self.version = version
        }
    }
}
