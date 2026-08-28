import Agentic
import AgenticWorkspace

public struct ToolInvoker: Sendable {
    public let registry: ToolRegistry
    public let policy: ToolExecutionPolicy

    public init(
        registry: ToolRegistry,
        policy: ToolExecutionPolicy
    ) {
        self.registry = registry
        self.policy = policy
    }

    public func review(
        _ call: AgentToolCall,
        execution: ToolInvocation.Execution? = nil,
        context: AgentToolExecutionContext = .init()
    ) async throws -> ToolInvocation.Review {
        let context = try targetedContext(
            for: call,
            execution: execution,
            context: context
        )

        let preflight = try await registry.preflight(
            call,
            context: context
        )

        return .init(
            call: call,
            preflight: preflight,
            requirement: policy.evaluate(
                preflight
            ),
            guidelineRelations: context.guidelineRelations
        )
    }

    public func invoke(
        _ call: AgentToolCall,
        execution: ToolInvocation.Execution? = nil,
        context: AgentToolExecutionContext = .init(),
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> ToolInvocation.Result {
        let context = try targetedContext(
            for: call,
            execution: execution,
            context: context
        )

        let review = try await review(
            call,
            context: context
        )

        let decision: ApprovalDecision

        switch review.requirement {
        case .no_approval_needed:
            decision = .approved

        case .needs_human_review:
            guard let approvalHandler else {
                return .init(
                    review: review,
                    decision: .needshuman,
                    toolResult: nil
                )
            }

            decision = try await approvalHandler.decide(
                on: review
            )

        case .denied_forbidden:
            decision = .denied
        }

        guard decision == .approved else {
            return .init(
                review: review,
                decision: decision,
                toolResult: nil
            )
        }

        let toolResult = try await registry.execute(
            call,
            context: context
        )

        return .init(
            review: review,
            decision: decision,
            toolResult: toolResult
        )
    }

    public func invoke(
        _ plan: AgentToolPlan,
        context: AgentToolExecutionContext = .init(),
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> AgentToolPlanResult {
        try await AgentToolPlanExecutor(
            invoker: self
        ).execute(
            plan,
            context: context,
            approvalHandler: approvalHandler
        )
    }
}

private extension ToolInvoker {
    func targetedContext(
        for call: AgentToolCall,
        execution: ToolInvocation.Execution?,
        context: AgentToolExecutionContext
    ) throws -> AgentToolExecutionContext {
        guard let target = execution?.workspace else {
            return context
        }

        guard let tool = registry.tool(
            named: call.name
        ) else {
            throw ToolDispatchError.unknownTool(
                call.name
            )
        }

        guard tool is any WorkspaceTargetableTool else {
            throw WorkspaceToolTargetingError.unsupportedTool(
                call.name
            )
        }

        guard let workspace = context.workspace else {
            throw WorkspaceToolTargetingError.workspaceRequired(
                call.name
            )
        }

        return context.withWorkspaceLocation(
            try workspace.location(
                for: target
            )
        )
    }
}
