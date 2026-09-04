import Schema

public enum PreparedIntentReviewDecision:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable,
    JSONSchemaProviding
{
    case approve
    case deny
    case cancel
    case expire

    public static var jsonschema: JSONSchema {
        .string(
            cases: allCases.map(\.rawValue)
        )
    }
}

public extension PreparedIntentReviewDecision {
    var resolvedStatus: PreparedIntentStatus {
        switch self {
        case .approve:
            return .approved

        case .deny:
            return .denied

        case .cancel:
            return .cancelled

        case .expire:
            return .expired
        }
    }
}
