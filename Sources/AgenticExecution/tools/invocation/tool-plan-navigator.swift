import Agentic

extension ToolPlan {
    struct Navigator:
        Sendable
    {
        struct Step:
            Sendable
        {
            let path: String
            let call: ToolCall
            let node: ToolPlan.Node
        }

        enum Traversal:
            Sendable
        {
            case next(Step)
            case complete(ToolPlan.Outcome)
        }

        struct ContinuationStep:
            Sendable
        {
            let path: String
            let node: ToolPlan.Node
        }

        struct Branch:
            Sendable
        {
            enum Label:
                String,
                Sendable,
                Hashable
            {
                case onSuccess
                case onFailure
                case onDenied
            }

            let label: Label
            let nodes: [ToolPlan.Node]
        }

        let plan: ToolPlan

        init(
            _ plan: ToolPlan
        ) {
            self.plan = plan
        }

        var rootPath: String {
            "root"
        }

        func node(
            containingCallID callID: String
        ) -> ToolPlan.Node? {
            node(
                plan.root,
                containingCallID: callID
            )
        }

        /// Derive untouched continuation only through ordinary sequence ancestry.
        ///
        /// Returning nil means the call exists only through ancestry whose resume
        /// semantics are intentionally not inferred yet, such as batch or an
        /// outcome branch. Returning an empty array means the call is a supported
        /// continuation point but nothing follows it.
        func sequenceContinuation(
            afterCallID callID: String
        ) -> [ContinuationStep]? {
            sequenceContinuation(
                plan.root,
                afterCallID: callID,
                path: rootPath
            )
        }

        func singleStepTraversal(
            outcomesByPath: [String: ToolPlan.Outcome]
        ) -> Traversal {
            singleStepTraversal(
                plan.root,
                path: rootPath,
                outcomesByPath: outcomesByPath
            )
        }

        func remap(
            _ result: ToolPlan.Result,
            planID: String? = nil,
            beneath path: String
        ) -> ToolPlan.Result {
            ToolPlan.Result(
                planID: planID ?? result.planID,
                outcome: result.outcome,
                records: result.records.map { record in
                    ToolPlan.Record(
                        path: Self.remappedPath(
                            record.path,
                            beneath: path
                        ),
                        call: record.call,
                        outcome: record.outcome,
                        invocation: record.invocation,
                        toolFailure: record.toolFailure,
                        errorDescription: record.errorDescription,
                        skipReason: record.skipReason
                    )
                }
            )
        }

        static func remappedPath(
            _ path: String,
            beneath originalPath: String
        ) -> String {
            let rootPath = "root"

            guard path != rootPath else {
                return originalPath
            }

            guard path.hasPrefix(
                "\(rootPath)."
            ) else {
                return path
            }

            return originalPath
                + String(
                    path.dropFirst(
                        rootPath.count
                    )
                )
        }

        func sequencePath(
            beneath path: String,
            component: String? = "sequence",
            index: Int
        ) -> String {
            guard let component else {
                return "\(path)[\(index)]"
            }

            return "\(path).\(component)[\(index)]"
        }

        func childPath(
            beneath path: String,
            kind: ToolPlan.Node.Kind,
            index: Int
        ) -> String {
            "\(path).\(kind.rawValue)[\(index)]"
        }

        func branchPath(
            beneath path: String,
            label: Branch.Label,
            index: Int
        ) -> String {
            "\(path).\(label.rawValue)[\(index)]"
        }

        func branch(
            for outcome: ToolPlan.Outcome,
            node: ToolPlan.Node
        ) -> Branch? {
            switch outcome {
            case .succeeded:
                return Branch(
                    label: .onSuccess,
                    nodes: node.onSuccess
                )

            case .failed:
                return Branch(
                    label: .onFailure,
                    nodes: node.onFailure
                )

            case .denied:
                return Branch(
                    label: .onDenied,
                    nodes: node.onDenied
                )

            case .needs_human_review,
                 .skipped,
                 .mixed:
                return nil
            }
        }

        func branches(
            of node: ToolPlan.Node
        ) -> [Branch] {
            [
                Branch(
                    label: .onSuccess,
                    nodes: node.onSuccess
                ),
                Branch(
                    label: .onFailure,
                    nodes: node.onFailure
                ),
                Branch(
                    label: .onDenied,
                    nodes: node.onDenied
                ),
            ]
        }

        func finalOutcome(
            outcome: ToolPlan.Outcome,
            selectedOutcome: ToolPlan.Outcome
        ) -> ToolPlan.Outcome {
            switch outcome {
            case .succeeded:
                return selectedOutcome

            case .failed,
                 .denied:
                return selectedOutcome == .needs_human_review
                    ? .needs_human_review
                    : outcome

            case .needs_human_review:
                return .needs_human_review

            case .skipped:
                return .succeeded

            case .mixed:
                return .mixed
            }
        }

        func aggregate(
            _ outcomes: [ToolPlan.Outcome]
        ) -> ToolPlan.Outcome {
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
            for node: ToolPlan.Node,
            path: String,
            reason: String
        ) -> [ToolPlan.Record] {
            switch node.kind {
            case .call:
                guard let call = node.call else {
                    return []
                }

                var records = [
                    ToolPlan.Record(
                        path: path,
                        call: call,
                        outcome: .skipped,
                        skipReason: reason
                    ),
                ]

                for branch in branches(
                    of: node
                ) {
                    records.append(
                        contentsOf: branch.nodes.enumerated().flatMap {
                            index,
                            branchNode in

                            skippedRecords(
                                for: branchNode,
                                path: branchPath(
                                    beneath: path,
                                    label: branch.label,
                                    index: index
                                ),
                                reason: reason
                            )
                        }
                    )
                }

                return records

            case .sequence,
                 .batch:
                return node.children.enumerated().flatMap {
                    index,
                    child in

                    skippedRecords(
                        for: child,
                        path: childPath(
                            beneath: path,
                            kind: node.kind,
                            index: index
                        ),
                        reason: reason
                    )
                }
            }
        }
    }
}

private extension ToolPlan.Navigator {
    func node(
        _ candidate: ToolPlan.Node,
        containingCallID callID: String
    ) -> ToolPlan.Node? {
        switch candidate {
        case .call(
            let call,
            _,
            let onSuccess,
            let onFailure,
            let onDenied
        ):
            if call.id == callID {
                return candidate
            }

            return (
                onSuccess
                + onFailure
                + onDenied
            ).lazy.compactMap { child in
                node(
                    child,
                    containingCallID: callID
                )
            }.first

        case .sequence(let children),
             .batch(let children):
            return children.lazy.compactMap { child in
                node(
                    child,
                    containingCallID: callID
                )
            }.first
        }
    }

    func sequenceContinuation(
        _ candidate: ToolPlan.Node,
        afterCallID callID: String,
        path: String
    ) -> [ContinuationStep]? {
        switch candidate {
        case .call(
            let call,
            _,
            _,
            _,
            _
        ):
            return call.id == callID
                ? []
                : nil

        case .sequence(let children):
            for (
                index,
                child
            ) in children.enumerated() {
                let childPath = sequencePath(
                    beneath: path,
                    index: index
                )

                guard let nested = sequenceContinuation(
                    child,
                    afterCallID: callID,
                    path: childPath
                ) else {
                    continue
                }

                let remaining = children.indices.compactMap {
                    remainingIndex -> ContinuationStep? in

                    guard remainingIndex > index else {
                        return nil
                    }

                    return ContinuationStep(
                        path: sequencePath(
                            beneath: path,
                            index: remainingIndex
                        ),
                        node: children[remainingIndex]
                    )
                }

                return nested + remaining
            }

            return nil

        case .batch:
            return nil
        }
    }

    func singleStepTraversal(
        _ node: ToolPlan.Node,
        path: String,
        outcomesByPath: [String: ToolPlan.Outcome]
    ) -> Traversal {
        switch node {
        case .call(
            let call,
            let execution,
            _,
            _,
            _
        ):
            guard let outcome = outcomesByPath[path] else {
                return .next(
                    Step(
                        path: path,
                        call: call,
                        node: .call(
                            call,
                            execution: execution
                        )
                    )
                )
            }

            let selectedOutcome: ToolPlan.Outcome

            if let selectedBranch = branch(
                for: outcome,
                node: node
            ) {
                let branchTraversal = sequenceTraversal(
                    selectedBranch.nodes,
                    path: "\(path).\(selectedBranch.label.rawValue)",
                    pathComponent: nil,
                    outcomesByPath: outcomesByPath
                )

                switch branchTraversal {
                case .next:
                    return branchTraversal

                case .complete(let outcome):
                    selectedOutcome = outcome
                }
            } else {
                selectedOutcome = .succeeded
            }

            return .complete(
                finalOutcome(
                    outcome: outcome,
                    selectedOutcome: selectedOutcome
                )
            )

        case .sequence(let children):
            return sequenceTraversal(
                children,
                path: path,
                pathComponent: "sequence",
                outcomesByPath: outcomesByPath
            )

        case .batch(let children):
            var outcomes: [ToolPlan.Outcome] = []

            for (
                index,
                child
            ) in children.enumerated() {
                let traversal = singleStepTraversal(
                    child,
                    path: childPath(
                        beneath: path,
                        kind: .batch,
                        index: index
                    ),
                    outcomesByPath: outcomesByPath
                )

                switch traversal {
                case .next:
                    return traversal

                case .complete(let outcome):
                    outcomes.append(
                        outcome
                    )

                    if outcome == .needs_human_review {
                        return .complete(
                            .needs_human_review
                        )
                    }
                }
            }

            return .complete(
                aggregate(
                    outcomes
                )
            )
        }
    }

    func sequenceTraversal(
        _ children: [ToolPlan.Node],
        path: String,
        pathComponent: String?,
        outcomesByPath: [String: ToolPlan.Outcome]
    ) -> Traversal {
        for (
            index,
            child
        ) in children.enumerated() {
            let traversal = singleStepTraversal(
                child,
                path: sequencePath(
                    beneath: path,
                    component: pathComponent,
                    index: index
                ),
                outcomesByPath: outcomesByPath
            )

            switch traversal {
            case .next:
                return traversal

            case .complete(let outcome):
                guard outcome == .succeeded else {
                    return .complete(
                        outcome
                    )
                }
            }
        }

        return .complete(
            .succeeded
        )
    }

}
