import Agentic
import Foundation

public struct ToolInspectionDocument: Sendable, Codable, Hashable {
    public var title: String
    public var sections: [ToolInspectionSection]

    public init(
        title: String,
        sections: [ToolInspectionSection] = []
    ) {
        self.title = title
        self.sections = sections
    }
}

public struct ToolInspectionSection: Sendable, Codable, Hashable {
    public var title: String
    public var items: [ToolInspectionItem]

    public init(
        title: String,
        items: [ToolInspectionItem] = []
    ) {
        self.title = title
        self.items = items
    }
}

public enum ToolInspectionItem: Sendable, Codable, Hashable {
    case field(
        label: String,
        value: String
    )

    case list(
        label: String,
        values: [String]
    )

    case body(
        String
    )
}

public extension ToolPreflight {
    func inspectionDocument(
        title: String = "Tool preflight details",
        toolName: String? = nil,
        toolCallID: String? = nil,
        requirement: ApprovalRequirement? = nil
    ) -> ToolInspectionDocument {
        var sections: [ToolInspectionSection] = [
            summarySection(
                toolName: toolName,
                toolCallID: toolCallID,
                requirement: requirement
            )
        ]

        if let section = accessSection {
            sections.append(
                section
            )
        }

        if let section = estimateSection {
            sections.append(
                section
            )
        }

        if let section = previewSection {
            sections.append(
                section
            )
        }

        if let section = policySection {
            sections.append(
                section
            )
        }

        return .init(
            title: title,
            sections: sections
        )
    }
}

private extension ToolPreflight {
    func summarySection(
        toolName overrideToolName: String?,
        toolCallID: String?,
        requirement: ApprovalRequirement?
    ) -> ToolInspectionSection {
        var items: [ToolInspectionItem] = [
            .field(
                label: "tool",
                value: overrideToolName ?? tool.rawValue
            ),
            .field(
                label: "risk",
                value: risk.rawValue
            ),
            .field(
                label: "summary",
                value: summary
            ),
            .field(
                label: "preview",
                value: preview.isEmpty ? "no" : "yes"
            ),
        ]

        if let requirement {
            items.insert(
                .field(
                    label: "requirement",
                    value: requirement.rawValue
                ),
                at: 1
            )
        }

        if let toolCallID {
            items.append(
                .field(
                    label: "tool call id",
                    value: toolCallID
                )
            )
        }

        return .init(
            title: "Summary",
            items: items
        )
    }

    var accessSection: ToolInspectionSection? {
        var items: [ToolInspectionItem] = []

        appendList(
            label: "roots",
            values: access.roots,
            to: &items
        )

        appendList(
            label: "capabilities",
            values: access.capabilities.map(\.rawValue),
            to: &items
        )

        appendList(
            label: "targets",
            values: access.targets,
            to: &items
        )

        if access.includesHidden {
            items.append(
                .field(
                    label: "hidden paths",
                    value: "included"
                )
            )
        }

        if access.followsSymlinks {
            items.append(
                .field(
                    label: "symlinks",
                    value: "followed"
                )
            )
        }

        guard !items.isEmpty else {
            return nil
        }

        return .init(
            title: "Access",
            items: items
        )
    }

    var estimateSection: ToolInspectionSection? {
        var items: [ToolInspectionItem] = []

        appendPositiveField(
            label: "writes",
            value: estimates.write.count,
            to: &items
        )

        appendOptionalField(
            label: "bytes",
            value: estimates.bytes,
            to: &items
        )

        appendOptionalField(
            label: "seconds",
            value: estimates.runtime,
            to: &items
        )

        appendOptionalField(
            label: "scan entries",
            value: estimates.scan.entries,
            to: &items
        )

        appendOptionalField(
            label: "scan depth",
            value: estimates.scan.depth,
            to: &items
        )

        appendOptionalField(
            label: "read bytes",
            value: estimates.read.bytes,
            to: &items
        )

        appendOptionalField(
            label: "read lines",
            value: estimates.read.lines,
            to: &items
        )

        appendOptionalField(
            label: "files read",
            value: estimates.read.files,
            to: &items
        )

        appendOptionalField(
            label: "write bytes",
            value: estimates.write.bytes,
            to: &items
        )

        appendOptionalField(
            label: "changed lines",
            value: estimates.write.changedLines,
            to: &items
        )

        appendOptionalField(
            label: "tool output bytes",
            value: estimates.outputBytes,
            to: &items
        )

        appendOptionalField(
            label: "context bytes",
            value: estimates.context.bytes,
            to: &items
        )

        appendOptionalField(
            label: "context tokens",
            value: estimates.context.tokens,
            to: &items
        )

        appendOptionalField(
            label: "context files",
            value: estimates.context.files,
            to: &items
        )

        appendOptionalField(
            label: "largest source tokens",
            value: estimates.context.largestSourceTokens,
            to: &items
        )

        guard !items.isEmpty else {
            return nil
        }

        return .init(
            title: "Estimates",
            items: items
        )
    }

    var previewSection: ToolInspectionSection? {
        var items: [ToolInspectionItem] = []

        appendOptionalField(
            label: "command",
            value: preview.command,
            to: &items
        )

        if let difference = preview.difference {
            items.append(
                .field(
                    label: "diff",
                    value: "\(difference.layout.changes.insertions.count) insertions, \(difference.layout.changes.deletions.count) deletions"
                )
            )
        }

        guard !items.isEmpty else {
            return nil
        }

        return .init(
            title: "Preview",
            items: items
        )
    }

    var policySection: ToolInspectionSection? {
        var items: [ToolInspectionItem] = []

        appendList(
            label: "policy checks",
            values: policyChecks,
            to: &items
        )

        appendList(
            label: "side effects",
            values: sideEffects,
            to: &items
        )

        appendList(
            label: "warnings",
            values: warnings,
            to: &items
        )

        guard !items.isEmpty else {
            return nil
        }

        return .init(
            title: "Policy",
            items: items
        )
    }
}

private func appendOptionalField(
    label: String,
    value: String?,
    to items: inout [ToolInspectionItem]
) {
    guard let value,
          !value.isEmpty
    else {
        return
    }

    items.append(
        .field(
            label: label,
            value: value
        )
    )
}

private func appendOptionalField<T>(
    label: String,
    value: T?,
    to items: inout [ToolInspectionItem]
) {
    guard let value else {
        return
    }

    items.append(
        .field(
            label: label,
            value: "\(value)"
        )
    )
}

private func appendPositiveField(
    label: String,
    value: Int,
    to items: inout [ToolInspectionItem]
) {
    guard value > 0 else {
        return
    }

    items.append(
        .field(
            label: label,
            value: "\(value)"
        )
    )
}

private func appendList(
    label: String,
    values: [String],
    to items: inout [ToolInspectionItem]
) {
    guard !values.isEmpty else {
        return
    }

    items.append(
        .list(
            label: label,
            values: values
        )
    )
}
