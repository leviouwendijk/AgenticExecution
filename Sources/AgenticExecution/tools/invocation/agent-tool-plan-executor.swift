import Agentic
import Foundation

public struct AgentToolPlanExecutor:
    Sendable
{
    public let invoker: ToolInvoker

    public init(
        invoker: ToolInvoker
    ) {
        self.invoker = invoker
    }

    public func execute(
        _ plan: AgentToolPlan,
        context: AgentToolExecutionContext = .init(),
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) async throws -> AgentToolPlanResult {
        try plan.validate()

        let context = context.appendingGuidelineRelations(
            plan.guidelineRelations
        )

        let execution = await execute(
            plan.root,
            path: "root",
            context: context,
            approvalHandler: approvalHandler
        )

        return .init(
            planID: plan.id,
            outcome: execution.outcome,
            records: execution.records
        )
    }
}

private extension AgentToolPlanExecutor {
    struct NodeExecution:
        Sendable
    {
        let outcome: AgentToolPlanOutcome
        let records: [AgentToolPlanRecord]
    }

    func execute(
        _ node: AgentToolPlanNode,
        path: String,
        context: AgentToolExecutionContext,
        approvalHandler: (any ToolApprovalHandler)?
    ) async -> NodeExecution {
        switch node.kind {
        case .call:
            return await executeCall(
                node,
                path: path,
                context: context,
                approvalHandler: approvalHandler
            )

        case .sequence:
            return await executeSequence(
                node.children,
                path: path,
                context: context,
                approvalHandler: approvalHandler
            )

        case .batch:
            return await executeBatch(
                node.children,
                path: path,
                context: context,
                approvalHandler: approvalHandler
            )
        }
    }

    func executeCall(
        _ node: AgentToolPlanNode,
        path: String,
        context: AgentToolExecutionContext,
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
                context: context,
                approvalHandler: approvalHandler
            )
        } catch {
            let record = AgentToolPlanRecord(
                path: path,
                call: call,
                outcome: .failed,
                toolFailure:
                    (error as? AgentToolCallError)?
                        .failure,
                errorDescription: errorText(
                    error
                )
            )

            let branches = await branchRecords(
                for: .failed,
                node: node,
                path: path,
                context: context,
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

        let record = AgentToolPlanRecord(
            path: path,
            call: call,
            outcome: outcome,
            invocation: invocation
        )

        let branches = await branchRecords(
            for: outcome,
            node: node,
            path: path,
            context: context,
            approvalHandler: approvalHandler
        )

        let finalOutcome: AgentToolPlanOutcome

        switch outcome {
        case .succeeded:
            finalOutcome = branches.selectedOutcome

        case .failed,
             .denied:
            finalOutcome =
                branches.selectedOutcome == .needs_human_review
                    ? .needs_human_review
                    : outcome

        case .needs_human_review:
            finalOutcome = .needs_human_review

        case .skipped:
            finalOutcome = .succeeded

        case .mixed:
            finalOutcome = .mixed
        }

        return .init(
            outcome: finalOutcome,
            records:
                [record]
                + branches.records
        )
    }

    func executeSequence(
        _ nodes: [AgentToolPlanNode],
        path: String,
        pathComponent: String? = "sequence",
        context: AgentToolExecutionContext,
        approvalHandler: (any ToolApprovalHandler)?
    ) async -> NodeExecution {
        var records: [AgentToolPlanRecord] = []

        for (
            index,
            node
        ) in nodes.enumerated() {
            let childPath: String

            if let pathComponent {
                childPath =
                    "\(path).\(pathComponent)[\(index)]"
            } else {
                childPath =
                    "\(path)[\(index)]"
            }

            let child = await execute(
                node,
                path: childPath,
                context: context,
                approvalHandler: approvalHandler
            )

            records.append(
                contentsOf: child.records
            )

            guard child.outcome == .succeeded else {
                for remainingIndex in nodes.indices where remainingIndex > index {
                    let remainingPath: String

                    if let pathComponent {
                        remainingPath =
                            "\(path).\(pathComponent)[\(remainingIndex)]"
                    } else {
                        remainingPath =
                            "\(path)[\(remainingIndex)]"
                    }

                    records.append(
                        contentsOf: skippedRecords(
                            for: nodes[remainingIndex],
                            path: remainingPath,
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
        _ nodes: [AgentToolPlanNode],
        path: String,
        context: AgentToolExecutionContext,
        approvalHandler: (any ToolApprovalHandler)?
    ) async -> NodeExecution {
        var records: [AgentToolPlanRecord] = []
        var outcomes: [AgentToolPlanOutcome] = []

        for (
            index,
            node
        ) in nodes.enumerated() {
            let childPath =
                "\(path).batch[\(index)]"

            let child = await execute(
                node,
                path: childPath,
                context: context,
                approvalHandler: approvalHandler
            )

            records.append(
                contentsOf: child.records
            )

            outcomes.append(
                child.outcome
            )

            if child.outcome == .needs_human_review {
                for remainingIndex in nodes.indices where remainingIndex > index {
                    records.append(
                        contentsOf: skippedRecords(
                            for: nodes[remainingIndex],
                            path: "\(path).batch[\(remainingIndex)]",
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
            outcome: aggregate(
                outcomes
            ),
            records: records
        )
    }

    func branchRecords(
        for outcome: AgentToolPlanOutcome,
        node: AgentToolPlanNode,
        path: String,
        context: AgentToolExecutionContext,
        approvalHandler: (any ToolApprovalHandler)?
    ) async -> (
        selectedOutcome: AgentToolPlanOutcome,
        records: [AgentToolPlanRecord]
    ) {
        let selectedLabel: String?
        let selectedNodes: [AgentToolPlanNode]

        switch outcome {
        case .succeeded:
            selectedLabel = "onSuccess"
            selectedNodes = node.onSuccess

        case .failed:
            selectedLabel = "onFailure"
            selectedNodes = node.onFailure

        case .denied:
            selectedLabel = "onDenied"
            selectedNodes = node.onDenied

        case .needs_human_review,
             .skipped,
             .mixed:
            selectedLabel = nil
            selectedNodes = []
        }

        var records: [AgentToolPlanRecord] = []
        var selectedOutcome: AgentToolPlanOutcome = .succeeded

        if let selectedLabel {
            let selected = await executeSequence(
                selectedNodes,
                path: "\(path).\(selectedLabel)",
                pathComponent: nil,
                context: context,
                approvalHandler: approvalHandler
            )

            selectedOutcome = selected.outcome

            records.append(
                contentsOf: selected.records
            )
        }

        let branches: [
            (
                label: String,
                nodes: [AgentToolPlanNode]
            )
        ] = [
            (
                "onSuccess",
                node.onSuccess
            ),
            (
                "onFailure",
                node.onFailure
            ),
            (
                "onDenied",
                node.onDenied
            ),
        ]

        for branch in branches where branch.label != selectedLabel {
            for (
                index,
                branchNode
            ) in branch.nodes.enumerated() {
                records.append(
                    contentsOf: skippedRecords(
                        for: branchNode,
                        path: "\(path).\(branch.label)[\(index)]",
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
    ) -> AgentToolPlanOutcome {
        switch invocation.decision {
        case .approved:
            guard let result = invocation.toolResult else {
                return .failed
            }

            return result.isError
                ? .failed
                : .succeeded

        case .denied:
            return .denied

        case .skipped:
            return .skipped

        case .needshuman:
            return .needs_human_review
        }
    }

    func aggregate(
        _ outcomes: [AgentToolPlanOutcome]
    ) -> AgentToolPlanOutcome {
        guard let first = outcomes.first else {
            return .succeeded
        }

        return outcomes.dropFirst().allSatisfy {
            $0 == first
        }
            ? first
            : .mixed
    }

    func skippedRecords(
        for node: AgentToolPlanNode,
        path: String,
        reason: String
    ) -> [AgentToolPlanRecord] {
        switch node.kind {
        case .call:
            guard let call = node.call else {
                return []
            }

            var records = [
                AgentToolPlanRecord(
                    path: path,
                    call: call,
                    outcome: .skipped,
                    skipReason: reason
                )
            ]

            records.append(
                contentsOf: skippedBranchRecords(
                    node.onSuccess,
                    label: "onSuccess",
                    path: path,
                    reason: reason
                )
            )

            records.append(
                contentsOf: skippedBranchRecords(
                    node.onFailure,
                    label: "onFailure",
                    path: path,
                    reason: reason
                )
            )

            records.append(
                contentsOf: skippedBranchRecords(
                    node.onDenied,
                    label: "onDenied",
                    path: path,
                    reason: reason
                )
            )

            return records

        case .sequence,
             .batch:
            return node.children.enumerated().flatMap {
                index,
                child in

                skippedRecords(
                    for: child,
                    path: "\(path).\(node.kind.rawValue)[\(index)]",
                    reason: reason
                )
            }
        }
    }

    func skippedBranchRecords(
        _ nodes: [AgentToolPlanNode],
        label: String,
        path: String,
        reason: String
    ) -> [AgentToolPlanRecord] {
        nodes.enumerated().flatMap {
            index,
            node in

            skippedRecords(
                for: node,
                path: "\(path).\(label)[\(index)]",
                reason: reason
            )
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