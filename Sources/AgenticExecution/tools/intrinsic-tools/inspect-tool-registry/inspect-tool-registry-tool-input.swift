import Schema
import SchemaMacros

/// Inspect the captured declared Agentic tool registry without changing model-visible tool exposure.
@JSONSchema
public struct InspectToolRegistryToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Optional exact registered tool identifier. Omit to list the captured declared registry.
    public let identifier: String?

    /// Whether to include lowered semantic input schemas in the returned entries. Defaults to false.
    public let includeSchemas: Bool?

    public init(
        identifier: String? = nil,
        includeSchemas: Bool? = nil
    ) {
        self.identifier = identifier
        self.includeSchemas = includeSchemas
    }

    public var resolvedIncludeSchemas: Bool {
        includeSchemas ?? false
    }
}
