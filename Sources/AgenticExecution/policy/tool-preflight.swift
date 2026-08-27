import Agentic
import AgenticWorkspace
import Foundation

public struct ToolPreflight: Sendable, Codable, Hashable, CustomStringConvertible {
    public let toolName: String
    public let risk: ActionRisk
    public let workspaceRoot: String?
    public let targetPaths: [String]
    public let summary: String
    public let commandPreview: String?
    public let estimatedWriteCount: Int
    public let estimatedByteCount: Int?
    public let estimatedRuntimeSeconds: TimeInterval?
    public let sideEffects: [String]
    public let limits: ExecutionLimits?

    public let rootIDs: [String]
    public let capabilitiesRequired: [PathCapability]
    public let estimatedScanEntries: Int?
    public let estimatedScanDepth: Int?
    public let estimatedReadBytes: Int?
    public let estimatedReadLines: Int?
    public let estimatedFileReadCount: Int?
    public let estimatedWriteBytes: Int?
    public let estimatedChangedLineCount: Int?
    public let estimatedToolOutputBytes: Int?
    public let estimatedContextBytes: Int?
    public let estimatedContextTokens: Int?
    public let estimatedContextFiles: Int?
    public let estimatedLargestSourceTokens: Int?
    public let includesHiddenPaths: Bool
    public let followsSymlinks: Bool
    public let isPreview: Bool
    public let policyChecks: [String]
    public let warnings: [String]
    public let limitProfile: String?
    public let diffPreview: ToolPreflightDiffPreview?

    public init(
        toolName: String,
        risk: ActionRisk,
        workspaceRoot: String? = nil,
        targetPaths: [String] = [],
        summary: String,
        commandPreview: String? = nil,
        estimatedWriteCount: Int = 0,
        estimatedByteCount: Int? = nil,
        estimatedRuntimeSeconds: TimeInterval? = nil,
        sideEffects: [String] = [],
        limits: ExecutionLimits? = nil,
        rootIDs: [String] = [],
        capabilitiesRequired: [PathCapability] = [],
        estimatedScanEntries: Int? = nil,
        estimatedScanDepth: Int? = nil,
        estimatedReadBytes: Int? = nil,
        estimatedReadLines: Int? = nil,
        estimatedFileReadCount: Int? = nil,
        estimatedWriteBytes: Int? = nil,
        estimatedChangedLineCount: Int? = nil,
        estimatedToolOutputBytes: Int? = nil,
        estimatedContextBytes: Int? = nil,
        estimatedContextTokens: Int? = nil,
        estimatedContextFiles: Int? = nil,
        estimatedLargestSourceTokens: Int? = nil,
        includesHiddenPaths: Bool = false,
        followsSymlinks: Bool = false,
        isPreview: Bool = false,
        policyChecks: [String] = [],
        warnings: [String] = [],
        limitProfile: String? = nil,
        diffPreview: ToolPreflightDiffPreview? = nil
    ) {
        self.toolName = toolName
        self.risk = risk
        self.workspaceRoot = workspaceRoot
        self.targetPaths = targetPaths
        self.summary = summary
        self.commandPreview = commandPreview
        self.estimatedWriteCount = max(
            0,
            estimatedWriteCount
        )
        self.estimatedByteCount = estimatedByteCount.map {
            max(
                0,
                $0
            )
        }
        self.estimatedRuntimeSeconds = estimatedRuntimeSeconds
        self.sideEffects = sideEffects
        self.limits = limits
        self.rootIDs = rootIDs
        self.capabilitiesRequired = capabilitiesRequired
        self.estimatedScanEntries = estimatedScanEntries.map {
            max(
                0,
                $0
            )
        }
        self.estimatedScanDepth = estimatedScanDepth.map {
            max(
                0,
                $0
            )
        }
        self.estimatedReadBytes = estimatedReadBytes.map {
            max(
                0,
                $0
            )
        }
        self.estimatedReadLines = estimatedReadLines.map {
            max(
                0,
                $0
            )
        }
        self.estimatedFileReadCount = estimatedFileReadCount.map {
            max(
                0,
                $0
            )
        }
        self.estimatedWriteBytes = estimatedWriteBytes.map {
            max(
                0,
                $0
            )
        }
        self.estimatedChangedLineCount = estimatedChangedLineCount.map {
            max(
                0,
                $0
            )
        }
        self.estimatedToolOutputBytes = estimatedToolOutputBytes.map {
            max(
                0,
                $0
            )
        }
        self.estimatedContextBytes = estimatedContextBytes.map {
            max(
                0,
                $0
            )
        }
        self.estimatedContextTokens = estimatedContextTokens.map {
            max(
                0,
                $0
            )
        }
        self.estimatedContextFiles = estimatedContextFiles.map {
            max(
                0,
                $0
            )
        }
        self.estimatedLargestSourceTokens = estimatedLargestSourceTokens.map {
            max(
                0,
                $0
            )
        }
        self.includesHiddenPaths = includesHiddenPaths
        self.followsSymlinks = followsSymlinks
        self.isPreview = isPreview
        self.policyChecks = policyChecks
        self.warnings = warnings
        self.limitProfile = limitProfile
        self.diffPreview = diffPreview
    }

    public var description: String {
        var lines: [String] = [
            "tool: \(toolName)",
            "risk: \(risk.rawValue)",
            "summary: \(summary)"
        ]

        if let workspaceRoot {
            lines.append(
                "workspace: \(workspaceRoot)"
            )
        }

        if !rootIDs.isEmpty {
            lines.append(
                "roots: \(rootIDs.joined(separator: ", "))"
            )
        }

        if !capabilitiesRequired.isEmpty {
            lines.append(
                "capabilities: \(capabilitiesRequired.map(\.rawValue).joined(separator: ", "))"
            )
        }

        if !targetPaths.isEmpty {
            lines.append(
                "targets: \(targetPaths.joined(separator: ", "))"
            )
        }

        if let commandPreview {
            lines.append(
                "command: \(commandPreview)"
            )
        }

        if estimatedWriteCount > 0 {
            lines.append(
                "estimated writes: \(estimatedWriteCount)"
            )
        }

        if let maximumEstimatedByteCount {
            lines.append(
                "estimated bytes: \(maximumEstimatedByteCount)"
            )
        }

        if let estimatedScanEntries {
            lines.append(
                "estimated scan entries: \(estimatedScanEntries)"
            )
        }

        if let estimatedReadLines {
            lines.append(
                "estimated read lines: \(estimatedReadLines)"
            )
        }

        if let estimatedRuntimeSeconds {
            lines.append(
                "estimated runtime: \(estimatedRuntimeSeconds)s"
            )
        }

        if includesHiddenPaths {
            lines.append(
                "includes hidden paths"
            )
        }

        if followsSymlinks {
            lines.append(
                "follows symlinks"
            )
        }

        if let diffPreview {
            lines.append(
                "diff preview: \(diffPreview.insertedLineCount) insertions, \(diffPreview.deletedLineCount) deletions"
            )
        }

        if !policyChecks.isEmpty {
            lines.append(
                "policy checks: \(policyChecks.joined(separator: ", "))"
            )
        }

        if !warnings.isEmpty {
            lines.append(
                "warnings: \(warnings.joined(separator: ", "))"
            )
        }

        if !sideEffects.isEmpty {
            lines.append(
                "side effects: \(sideEffects.joined(separator: ", "))"
            )
        }

        return lines.joined(
            separator: "\n"
        )
    }
}

public extension ToolPreflight {
    var maximumEstimatedByteCount: Int? {
        [
            estimatedByteCount,
            estimatedReadBytes,
            estimatedWriteBytes,
            estimatedToolOutputBytes,
            estimatedContextBytes
        ].compactMap {
            $0
        }.max()
    }

    var hasEstimatedFilesystemAccess: Bool {
        !targetPaths.isEmpty || !rootIDs.isEmpty || !capabilitiesRequired.isEmpty
    }
}
