import Primitives
import Schema

public protocol TypedAgentTool:
    StaticAgentTool
{
    associatedtype Input:
        Decodable &
        Sendable &
        JSONSchemaProviding

    associatedtype Output:
        Encodable &
        Sendable
}

public extension TypedAgentTool {
    static var inputSchema: JSONValue? {
        Input
            .jsonschema
            .jsonvalue
    }
}
