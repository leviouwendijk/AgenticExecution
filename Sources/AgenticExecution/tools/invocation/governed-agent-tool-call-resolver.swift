import Agentic
import Primitives

public enum AgentToolCallResolutionError:
    Error,
    Sendable
{
    case needsHumanReview(ToolInvocation.Review)
    case missingToolResult(
        call: AgentToolCall,
        decision: ApprovalDecision
    )
}

public struct GovernedAgentToolCallResolver:
    AgentToolCallResolver,
    Sendable
{
    public let registry: ToolRegistry
    public let exposure: AgentToolExposure
    public let invoker: ToolInvoker
    public let context: AgentToolExecutionContext
    public let approvalHandler: (any ToolApprovalHandler)?
    public let resolutionObserver:
        (@Sendable (ToolInvocation.Result) async -> Void)?

    public init(
        registry: ToolRegistry,
        exposure: AgentToolExposure,
        policy: ToolExecutionPolicy,
        context: AgentToolExecutionContext = .init(),
        approvalHandler: (any ToolApprovalHandler)? = nil,
        resolutionObserver:
            (@Sendable (ToolInvocation.Result) async -> Void)? = nil
    ) {
        self.registry = registry
        self.exposure = exposure
        self.invoker = ToolInvoker(
            registry: registry,
            policy: policy
        )
        self.context = context
        self.approvalHandler = approvalHandler
        self.resolutionObserver = resolutionObserver
    }

    public func resolve(
        _ call: AgentToolCall
    ) async throws -> AgentToolResult {
        let parsed = try await exposure.parseModelCall(
            call,
            registry: registry
        )

        let invocation = try await invoker.invoke(
            parsed.call,
            context: context.withExecutionMode(
                .model_tool_call
            ),
            approvalHandler: approvalHandler
        )

        await resolutionObserver?(
            invocation
        )

        if let result = invocation.toolResult {
            return result
        }

        switch invocation.decision {
        case .approved:
            throw AgentToolCallResolutionError.missingToolResult(
                call: parsed.call,
                decision: invocation.decision
            )

        case .needshuman:
            throw AgentToolCallResolutionError.needsHumanReview(
                invocation.review
            )

        case .denied:
            return try deniedResult(
                for: parsed.call,
                review: invocation.review
            )

        case .skipped:
            return try skippedResult(
                for: parsed.call,
                review: invocation.review
            )
        }
    }
}

private extension GovernedAgentToolCallResolver {
    struct ResolutionPayload:
        Sendable,
        Encodable
    {
        let kind: String
        let toolCallID: String
        let toolName: String
        let requirement: String
        let summary: String
    }

    func deniedResult(
        for call: AgentToolCall,
        review: ToolInvocation.Review
    ) throws -> AgentToolResult {
        AgentToolResult(
            toolCallID: call.id,
            name: call.name,
            output: try JSONToolBridge.encode(
                ResolutionPayload(
                    kind: "tool_denied",
                    toolCallID: call.id,
                    toolName: call.name,
                    requirement: review.requirement.rawValue,
                    summary: review.preflight.summary
                )
            ),
            isError: true
        )
    }

    func skippedResult(
        for call: AgentToolCall,
        review: ToolInvocation.Review
    ) throws -> AgentToolResult {
        AgentToolResult(
            toolCallID: call.id,
            name: call.name,
            output: try JSONToolBridge.encode(
                ResolutionPayload(
                    kind: "tool_skipped",
                    toolCallID: call.id,
                    toolName: call.name,
                    requirement: review.requirement.rawValue,
                    summary: "Skipped explicitly by the operator."
                )
            ),
            isError: false
        )
    }
}
