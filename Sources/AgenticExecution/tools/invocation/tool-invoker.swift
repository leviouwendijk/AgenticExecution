import Agentic
import Foundation
import Workspace

public struct ToolInvoker: Sendable {
    public let registry: ToolRegistry
    public let policy: ToolExecutionPolicy
    public let recovery: Recovery.Policy?

    public init(
        registry: ToolRegistry,
        policy: ToolExecutionPolicy,
        recovery: Recovery.Policy? = nil
    ) {
        self.registry = registry
        self.policy = policy
        self.recovery = recovery
    }

    public func review(
        _ call: ToolCall,
        execution: ToolInvocation.Execution? = nil,
        workspace: WorkspaceContext? = nil,
        guidelineRelations: [AgentGuidelineRelation] = []
    ) async throws -> ToolInvocation.Review {
        let workspace = try targetedWorkspace(
            for: call,
            execution: execution,
            workspace: workspace
        )

        let preflight = try await registry.preflight(
            call,
            workspace: workspace
        )

        return .init(
            call: call,
            preflight: preflight,
            requirement: policy.evaluate(
                preflight
            ),
            guidelineRelations: guidelineRelations
        )
    }

    public func invoke(
        _ call: ToolCall,
        execution: ToolInvocation.Execution? = nil,
        workspace: WorkspaceContext? = nil,
        guidelineRelations: [AgentGuidelineRelation] = [],
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> ToolInvocation.Result {
        let workspace = try targetedWorkspace(
            for: call,
            execution: execution,
            workspace: workspace
        )

        let review = try await review(
            call,
            workspace: workspace,
            guidelineRelations: guidelineRelations
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
                    execution: nil
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
                execution: nil
            )
        }

        let toolExecution = try await executeApproved(
            call,
            preflight: review.preflight,
            workspace: workspace
        )

        return .init(
            review: review,
            decision: decision,
            execution: toolExecution
        )
    }

    public func invoke(
        _ plan: ToolPlan,
        workspace: WorkspaceContext? = nil,
        guidelineRelations: [AgentGuidelineRelation] = [],
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> AgentToolPlanResult {
        try await AgentToolPlanExecutor(
            invoker: self
        ).execute(
            plan,
            workspace: workspace,
            guidelineRelations: guidelineRelations,
            approvalHandler: approvalHandler
        )
    }
}

private extension ToolInvoker {
    func targetedWorkspace(
        for call: ToolCall,
        execution: ToolInvocation.Execution?,
        workspace: WorkspaceContext?
    ) throws -> WorkspaceContext? {
        guard let target = execution?.workspace else {
            return workspace
        }

        guard let tool = registry.registeredTool(
            identifiedBy: call.tool
        ) else {
            throw ToolRegistryExecutionError.missingTool(
                call.tool.rawValue
            )
        }

        guard
            tool.capability.execution.workingLocation
                == AgentToolExecutionContract.WorkingLocation.targetable
        else {
            throw WorkspaceToolTargetingError.unsupportedTool(
                call.tool.rawValue
            )
        }

        guard let workspace else {
            throw WorkspaceToolTargetingError.workspaceRequired(
                call.tool.rawValue
            )
        }

        let subpath = target.subpath.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !subpath.isEmpty else {
            throw WorkspaceToolTargetingError.emptySubpath
        }

        return try workspace.context(
            atRootPath: subpath
        )
    }
}
