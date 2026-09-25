import Agentic
import Foundation
import Workspace

public struct ToolPlanExecutor:
    Sendable
{
    public let invoker: ToolInvoker

    public init(
        invoker: ToolInvoker
    ) {
        self.invoker = invoker
    }

    public func execute(
        _ plan: ToolPlan,
        workspace: WorkspaceContext? = nil,
        guidelineRelations: [AgentGuidelineRelation] = [],
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> ToolPlan.Result {
        var guidelineRelations = guidelineRelations

        for relation in plan.guidelines
        where !guidelineRelations.contains(relation)
        {
            guidelineRelations.append(relation)
        }

        let navigator = ToolPlan.Navigator(
            plan
        )
        let execution = await execute(
            plan.root,
            path: navigator.rootPath,
            navigator: navigator,
            workspace: workspace,
            guidelineRelations: guidelineRelations,
            approvalHandler: approvalHandler
        )

        return .init(
            planID: plan.id,
            outcome: execution.outcome,
            records: execution.records
        )
    }
}

private extension ToolPlanExecutor {
    struct NodeExecution:
        Sendable
    {
        let outcome: ToolPlan.Outcome
        let records: [ToolPlan.Record]
    }

    func execute(
        _ node: ToolPlan.Node,
        path: String,
        navigator: ToolPlan.Navigator,
        workspace: WorkspaceContext?,
        guidelineRelations: [AgentGuidelineRelation],
        approvalHandler: (any ToolApprovalHandler)?
    ) async -> NodeExecution {
        switch node.kind {
        case .call:
            return await executeCall(
                node,
                path: path,
                navigator: navigator,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )

        case .sequence:
            return await executeSequence(
                node.children,
                path: path,
                navigator: navigator,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )

        case .batch:
            return await executeBatch(
                node.children,
                path: path,
                navigator: navigator,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )
        }
    }

    func executeCall(
        _ node: ToolPlan.Node,
        path: String,
        navigator: ToolPlan.Navigator,
        workspace: WorkspaceContext?,
        guidelineRelations: [AgentGuidelineRelation],
        approvalHandler: (any ToolApprovalHandler)?
    ) async -> NodeExecution {
        guard let call = node.call else {
            return .init(
                outcome: .failed,
                records: []
            )
        }

        let invocation: ToolInvocation.Result

        do {
            let execution = try node.execution.map {
                try JSONToolBridge.decode(
                    ToolInvocation.Execution.self,
                    from: $0
                )
            }

            invocation = try await invoker.invoke(
                call,
                execution: execution,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )
        } catch {
            let record = ToolPlan.Record(
                path: path,
                call: call,
                outcome: .failed,
                toolFailure:
                    (error as? ToolCall.Error)?
                        .failure,
                errorDescription: errorText(
                    error
                )
            )

            let branches = await branchRecords(
                for: .failed,
                node: node,
                path: path,
                navigator: navigator,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )

            return .init(
                outcome:
                    branches.selectedOutcome == .needs_human_review
                        ? .needs_human_review
                        : .failed,
                records:
                    [record]
                    + branches.records
            )
        }

        let outcome = outcome(
            for: invocation
        )
        let record = ToolPlan.Record(
            path: path,
            call: call,
            outcome: outcome,
            invocation: invocation,
            toolFailure: invocation.execution?.failure,
            errorDescription: invocation.execution?.failure?.message
        )
        let branches = await branchRecords(
            for: outcome,
            node: node,
            path: path,
            navigator: navigator,
            workspace: workspace,
            guidelineRelations: guidelineRelations,
            approvalHandler: approvalHandler
        )

        return .init(
            outcome: navigator.finalOutcome(
                outcome: outcome,
                selectedOutcome: branches.selectedOutcome
            ),
            records:
                [record]
                + branches.records
        )
    }

    func executeSequence(
        _ nodes: [ToolPlan.Node],
        path: String,
        pathComponent: String? = "sequence",
        navigator: ToolPlan.Navigator,
        workspace: WorkspaceContext?,
        guidelineRelations: [AgentGuidelineRelation],
        approvalHandler: (any ToolApprovalHandler)?
    ) async -> NodeExecution {
        var records: [ToolPlan.Record] = []

        for (
            index,
            node
        ) in nodes.enumerated() {
            let childPath = navigator.sequencePath(
                beneath: path,
                component: pathComponent,
                index: index
            )
            let child = await execute(
                node,
                path: childPath,
                navigator: navigator,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )

            records.append(
                contentsOf: child.records
            )

            guard child.outcome == .succeeded else {
                for remainingIndex in nodes.indices
                where remainingIndex > index
                {
                    records.append(
                        contentsOf: navigator.skippedRecords(
                            for: nodes[remainingIndex],
                            path: navigator.sequencePath(
                                beneath: path,
                                component: pathComponent,
                                index: remainingIndex
                            ),
                            reason: "sequence_stopped_after_\(child.outcome.rawValue)"
                        )
                    )
                }

                return .init(
                    outcome: child.outcome,
                    records: records
                )
            }
        }

        return .init(
            outcome: .succeeded,
            records: records
        )
    }

    func executeBatch(
        _ nodes: [ToolPlan.Node],
        path: String,
        navigator: ToolPlan.Navigator,
        workspace: WorkspaceContext?,
        guidelineRelations: [AgentGuidelineRelation],
        approvalHandler: (any ToolApprovalHandler)?
    ) async -> NodeExecution {
        var records: [ToolPlan.Record] = []
        var outcomes: [ToolPlan.Outcome] = []

        for (
            index,
            node
        ) in nodes.enumerated() {
            let childPath = navigator.childPath(
                beneath: path,
                kind: .batch,
                index: index
            )
            let child = await execute(
                node,
                path: childPath,
                navigator: navigator,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )

            records.append(
                contentsOf: child.records
            )
            outcomes.append(
                child.outcome
            )

            if child.outcome == .needs_human_review {
                for remainingIndex in nodes.indices
                where remainingIndex > index
                {
                    records.append(
                        contentsOf: navigator.skippedRecords(
                            for: nodes[remainingIndex],
                            path: navigator.childPath(
                                beneath: path,
                                kind: .batch,
                                index: remainingIndex
                            ),
                            reason: "batch_suspended_for_approval"
                        )
                    )
                }

                return .init(
                    outcome: .needs_human_review,
                    records: records
                )
            }
        }

        return .init(
            outcome: navigator.aggregate(
                outcomes
            ),
            records: records
        )
    }

    func branchRecords(
        for outcome: ToolPlan.Outcome,
        node: ToolPlan.Node,
        path: String,
        navigator: ToolPlan.Navigator,
        workspace: WorkspaceContext?,
        guidelineRelations: [AgentGuidelineRelation],
        approvalHandler: (any ToolApprovalHandler)?
    ) async -> (
        selectedOutcome: ToolPlan.Outcome,
        records: [ToolPlan.Record]
    ) {
        let selectedBranch = navigator.branch(
            for: outcome,
            node: node
        )

        var records: [ToolPlan.Record] = []
        var selectedOutcome: ToolPlan.Outcome = .succeeded

        if let selectedBranch {
            let selected = await executeSequence(
                selectedBranch.nodes,
                path: "\(path).\(selectedBranch.label.rawValue)",
                pathComponent: nil,
                navigator: navigator,
                workspace: workspace,
                guidelineRelations: guidelineRelations,
                approvalHandler: approvalHandler
            )

            selectedOutcome = selected.outcome
            records.append(
                contentsOf: selected.records
            )
        }

        for branch in navigator.branches(
            of: node
        )
        where branch.label != selectedBranch?.label
        {
            for (
                index,
                branchNode
            ) in branch.nodes.enumerated() {
                records.append(
                    contentsOf: navigator.skippedRecords(
                        for: branchNode,
                        path: navigator.branchPath(
                            beneath: path,
                            label: branch.label,
                            index: index
                        ),
                        reason: "condition_not_selected"
                    )
                )
            }
        }

        return (
            selectedOutcome,
            records
        )
    }

    func outcome(
        for invocation: ToolInvocation.Result
    ) -> ToolPlan.Outcome {
        switch invocation.outcome {
        case .executed(let execution):
            return execution.result.isError
                ? .failed
                : .succeeded

        case .denied:
            return .denied

        case .skipped:
            return .skipped

        case .interrupted(.human_review):
            return .needs_human_review
        }
    }

    func errorText(
        _ error: Error
    ) -> String {
        if let localized = error as? any LocalizedError,
           let description = localized.errorDescription
        {
            return description
        }

        return String(
            describing: error
        )
    }
}
