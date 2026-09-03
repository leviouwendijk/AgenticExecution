import Schema

/// Model-facing registration state captured when an AgentTool enters ToolRegistry.
public enum AgentToolModelContract: Sendable {
    case modelFacing(
        inputSchema: JSONSchema
    )

    case hostOnly

    public var semanticInputSchema: JSONSchema? {
        switch self {
        case .modelFacing(let inputSchema):
            inputSchema

        case .hostOnly:
            nil
        }
    }

    public var isModelFacing: Bool {
        switch self {
        case .modelFacing:
            true

        case .hostOnly:
            false
        }
    }
}
