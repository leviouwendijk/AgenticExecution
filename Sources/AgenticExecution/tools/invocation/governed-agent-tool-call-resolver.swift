import Agentic
import Primitives
import Workspace

public enum AgentToolCallResolutionError:
    Error,
    Sendable
{
    case needsHumanReview(ToolInvocation.Review)
}

public struct GovernedAgentToolCallResolver:
    ToolCallResolver,
    Sendable
{
    public let registry: ToolRegistry
    public let exposure: AgentToolExposure
    public let invoker: ToolInvoker
    public let workspace: WorkspaceContext?
    public let approvalHandler: (any ToolApprovalHandler)?
    public let resolutionObserver:
        (@Sendable (ToolInvocation.Result) async -> Void)?

    public init(
        registry: ToolRegistry,
        exposure: AgentToolExposure,
        policy: ToolExecutionPolicy,
        recovery: Recovery.Policy? = nil,
        workspace: WorkspaceContext? = nil,
        approvalHandler: (any ToolApprovalHandler)? = nil,
        resolutionObserver:
            (@Sendable (ToolInvocation.Result) async -> Void)? = nil
    ) {
        self.registry = registry
        self.exposure = exposure
        self.invoker = ToolInvoker(
            registry: registry,
            policy: policy,
            recovery: recovery
        )
        self.workspace = workspace
        self.approvalHandler = approvalHandler
        self.resolutionObserver = resolutionObserver
    }

    public func resolve(
        _ call: ToolCall
    ) async throws -> ToolResult {
        let parsed = try await exposure.parseModelCall(
            call,
            registry: registry
        )

        let invocation = try await invoker.invoke(
            parsed.call,
            workspace: workspace,
            approvalHandler: approvalHandler
        )

        await resolutionObserver?(
            invocation
        )

        switch invocation.outcome {
        case .executed(let execution):
            return execution.result

        case .interrupted(.human_review):
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
        for call: ToolCall,
        review: ToolInvocation.Review
    ) throws -> ToolResult {
        ToolResult(
            toolCallID: call.id,
            tool: call.tool,
            output: try JSONToolBridge.encode(
                ResolutionPayload(
                    kind: "tool_denied",
                    toolCallID: call.id,
                    toolName: call.tool.rawValue,
                    requirement: review.requirement.rawValue,
                    summary: review.preflight.summary
                )
            ),
            isError: true
        )
    }

    func skippedResult(
        for call: ToolCall,
        review: ToolInvocation.Review
    ) throws -> ToolResult {
        ToolResult(
            toolCallID: call.id,
            tool: call.tool,
            output: try JSONToolBridge.encode(
                ResolutionPayload(
                    kind: "tool_skipped",
                    toolCallID: call.id,
                    toolName: call.tool.rawValue,
                    requirement: review.requirement.rawValue,
                    summary: "Skipped explicitly by the operator."
                )
            ),
            isError: false
        )
    }
}
