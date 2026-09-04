import Schema
import SchemaMacros

@JSONSchema
public struct InspectToolExposureToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Defaults to false to keep the normal result compact.
    public let includeHiddenIdentifiers: Bool?

    public init(
        includeHiddenIdentifiers: Bool? = nil
    ) {
        self.includeHiddenIdentifiers = includeHiddenIdentifiers
    }

    public var resolvedIncludeHiddenIdentifiers: Bool {
        includeHiddenIdentifiers ?? false
    }
}
