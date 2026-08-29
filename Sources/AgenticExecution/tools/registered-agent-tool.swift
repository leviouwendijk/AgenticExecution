import Agentic
import Primitives
import Foundation

/// Type-erased registered tool plus the facts captured when it entered ToolRegistry.
public struct RegisteredAgentTool:
    Sendable
{
    public let tool: any AgentTool
    public let capability: AgentToolCapability

    private let registrationDescriptor: AgentToolRegistrationDescriptor

    public init(
        _ tool: any AgentTool
    ) {
        let registrationDescriptor =
            tool.registrationDescriptor

        self.tool = tool
        self.registrationDescriptor = registrationDescriptor
        self.capability = AgentToolCapability(
            definition: tool.definition,
            modelContract:
                registrationDescriptor.modelContract,
            supportsWorkspaceTargeting:
                tool is any WorkspaceTargetableTool
        )
    }

    public func parseModelCall(
        _ call: AgentToolCall
    ) throws -> ParsedAgentToolCall {
        let parsedInput: ParsedAgentToolInput

        do {
            parsedInput = try registrationDescriptor
                .parseModelInput(
                    call.input
                )
        } catch {
            throw RegisteredAgentToolError.invalidModelCall(
                tool: capability.definition.name,
                reason:
                    error.localizedDescription
            )
        }

        return ParsedAgentToolCall(
            call: AgentToolCall(
                id: call.id,
                name: call.name,
                input: parsedInput.jsonValue
            ),
            capability: capability
        )
    }
}

/// A model call that has resolved to one exact registered tool and crossed that
/// tool's captured typed input parser.
public struct ParsedAgentToolCall:
    Sendable
{
    public let call: AgentToolCall
    public let capability: AgentToolCapability

    fileprivate init(
        call: AgentToolCall,
        capability: AgentToolCapability
    ) {
        self.call = call
        self.capability = capability
    }
}

public enum RegisteredAgentToolError:
    Error,
    Sendable,
    LocalizedError
{
    case invalidModelCall(
        tool: String,
        reason: String
    )

    public var errorDescription: String? {
        switch self {
        case .invalidModelCall(
            let tool,
            let reason
        ):
            "Cannot parse model input for registered tool '\(tool)': \(reason)"
        }
    }
}
