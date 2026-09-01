public enum ToolPolicyDirective:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case require_human_review
    case require_deny
}
