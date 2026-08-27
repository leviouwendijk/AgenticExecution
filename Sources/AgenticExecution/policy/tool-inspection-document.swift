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
                value: overrideToolName ?? toolName
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
                value: isPreview ? "yes" : "no"
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

        appendOptionalField(
            label: "workspace",
            value: workspaceRoot,
            to: &items
        )

        appendList(
            label: "roots",
            values: rootIDs,
            to: &items
        )

        appendList(
            label: "capabilities",
            values: capabilitiesRequired.map(\.rawValue),
            to: &items
        )

        appendList(
            label: "targets",
            values: targetPaths,
            to: &items
        )

        if includesHiddenPaths {
            items.append(
                .field(
                    label: "hidden paths",
                    value: "included"
                )
            )
        }

        if followsSymlinks {
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
            value: estimatedWriteCount,
            to: &items
        )

        appendOptionalField(
            label: "bytes",
            value: estimatedByteCount,
            to: &items
        )

        appendOptionalField(
            label: "seconds",
            value: estimatedRuntimeSeconds,
            to: &items
        )

        appendOptionalField(
            label: "scan entries",
            value: estimatedScanEntries,
            to: &items
        )

        appendOptionalField(
            label: "scan depth",
            value: estimatedScanDepth,
            to: &items
        )

        appendOptionalField(
            label: "read bytes",
            value: estimatedReadBytes,
            to: &items
        )

        appendOptionalField(
            label: "read lines",
            value: estimatedReadLines,
            to: &items
        )

        appendOptionalField(
            label: "files read",
            value: estimatedFileReadCount,
            to: &items
        )

        appendOptionalField(
            label: "write bytes",
            value: estimatedWriteBytes,
            to: &items
        )

        appendOptionalField(
            label: "changed lines",
            value: estimatedChangedLineCount,
            to: &items
        )

        appendOptionalField(
            label: "tool output bytes",
            value: estimatedToolOutputBytes,
            to: &items
        )

        appendOptionalField(
            label: "context bytes",
            value: estimatedContextBytes,
            to: &items
        )

        appendOptionalField(
            label: "context tokens",
            value: estimatedContextTokens,
            to: &items
        )

        appendOptionalField(
            label: "context files",
            value: estimatedContextFiles,
            to: &items
        )

        appendOptionalField(
            label: "largest source tokens",
            value: estimatedLargestSourceTokens,
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
            value: commandPreview,
            to: &items
        )

        appendOptionalField(
            label: "limit profile",
            value: limitProfile,
            to: &items
        )

        if let diffPreview {
            items.append(
                .field(
                    label: "diff",
                    value: "\(diffPreview.insertedLineCount) insertions, \(diffPreview.deletedLineCount) deletions, context \(diffPreview.contextLineCount)"
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
