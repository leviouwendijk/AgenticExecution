import Foundation

public struct PathExecutionLimits: Sendable, Codable, Hashable {
    public var maxTargetPathCount: Int?
    public var maxScanEntries: Int?
    public var maxScanDepth: Int?
    public var allowHidden: Bool?
    public var allowSymlinks: Bool?
    public var maxRootsPerToolCall: Int?

    public init(
        maxTargetPathCount: Int? = nil,
        maxScanEntries: Int? = nil,
        maxScanDepth: Int? = nil,
        allowHidden: Bool? = nil,
        allowSymlinks: Bool? = nil,
        maxRootsPerToolCall: Int? = nil
    ) {
        self.maxTargetPathCount = maxTargetPathCount
        self.maxScanEntries = maxScanEntries
        self.maxScanDepth = maxScanDepth
        self.allowHidden = allowHidden
        self.allowSymlinks = allowSymlinks
        self.maxRootsPerToolCall = maxRootsPerToolCall
    }

    public static let unlimited = Self()
}

public extension PathExecutionLimits {
    var isUnlimited: Bool {
        maxTargetPathCount == nil
            && maxScanEntries == nil
            && maxScanDepth == nil
            && allowHidden == nil
            && allowSymlinks == nil
            && maxRootsPerToolCall == nil
    }

    func merged(
        with override: Self
    ) -> Self {
        .init(
            maxTargetPathCount: override.maxTargetPathCount ?? maxTargetPathCount,
            maxScanEntries: override.maxScanEntries ?? maxScanEntries,
            maxScanDepth: override.maxScanDepth ?? maxScanDepth,
            allowHidden: override.allowHidden ?? allowHidden,
            allowSymlinks: override.allowSymlinks ?? allowSymlinks,
            maxRootsPerToolCall: override.maxRootsPerToolCall ?? maxRootsPerToolCall
        )
    }
}

public struct ReadExecutionLimits: Sendable, Codable, Hashable {
    public var maxReadBytes: Int?
    public var maxReadLines: Int?
    public var maxFilesPerRead: Int?
    public var maxToolOutputBytes: Int?

    public init(
        maxReadBytes: Int? = nil,
        maxReadLines: Int? = nil,
        maxFilesPerRead: Int? = nil,
        maxToolOutputBytes: Int? = nil
    ) {
        self.maxReadBytes = maxReadBytes
        self.maxReadLines = maxReadLines
        self.maxFilesPerRead = maxFilesPerRead
        self.maxToolOutputBytes = maxToolOutputBytes
    }

    public static let unlimited = Self()
}

public extension ReadExecutionLimits {
    var isUnlimited: Bool {
        maxReadBytes == nil
            && maxReadLines == nil
            && maxFilesPerRead == nil
            && maxToolOutputBytes == nil
    }

    func merged(
        with override: Self
    ) -> Self {
        .init(
            maxReadBytes: override.maxReadBytes ?? maxReadBytes,
            maxReadLines: override.maxReadLines ?? maxReadLines,
            maxFilesPerRead: override.maxFilesPerRead ?? maxFilesPerRead,
            maxToolOutputBytes: override.maxToolOutputBytes ?? maxToolOutputBytes
        )
    }
}

public struct WriteExecutionLimits: Sendable, Codable, Hashable {
    public var maxWriteBytes: Int?
    public var maxWriteCount: Int?
    public var maxChangedLineCount: Int?
    public var requirePreviewForWrites: Bool?

    public init(
        maxWriteBytes: Int? = nil,
        maxWriteCount: Int? = nil,
        maxChangedLineCount: Int? = nil,
        requirePreviewForWrites: Bool? = nil
    ) {
        self.maxWriteBytes = maxWriteBytes
        self.maxWriteCount = maxWriteCount
        self.maxChangedLineCount = maxChangedLineCount
        self.requirePreviewForWrites = requirePreviewForWrites
    }

    public static let unlimited = Self()
}

public extension WriteExecutionLimits {
    var isUnlimited: Bool {
        maxWriteBytes == nil
            && maxWriteCount == nil
            && maxChangedLineCount == nil
            && requirePreviewForWrites == nil
    }

    func merged(
        with override: Self
    ) -> Self {
        .init(
            maxWriteBytes: override.maxWriteBytes ?? maxWriteBytes,
            maxWriteCount: override.maxWriteCount ?? maxWriteCount,
            maxChangedLineCount: override.maxChangedLineCount ?? maxChangedLineCount,
            requirePreviewForWrites: override.requirePreviewForWrites ?? requirePreviewForWrites
        )
    }
}

public struct ContextExecutionLimits: Sendable, Codable, Hashable {
    public var maxContextBytes: Int?
    public var maxContextTokens: Int?
    public var maxFiles: Int?
    public var maxLinesPerFile: Int?
    public var maxLargestSourceTokens: Int?

    public init(
        maxContextBytes: Int? = nil,
        maxContextTokens: Int? = nil,
        maxFiles: Int? = nil,
        maxLinesPerFile: Int? = nil,
        maxLargestSourceTokens: Int? = nil
    ) {
        self.maxContextBytes = maxContextBytes
        self.maxContextTokens = maxContextTokens
        self.maxFiles = maxFiles
        self.maxLinesPerFile = maxLinesPerFile
        self.maxLargestSourceTokens = maxLargestSourceTokens
    }

    public static let unlimited = Self()
}

public extension ContextExecutionLimits {
    var isUnlimited: Bool {
        maxContextBytes == nil
            && maxContextTokens == nil
            && maxFiles == nil
            && maxLinesPerFile == nil
            && maxLargestSourceTokens == nil
    }

    func merged(
        with override: Self
    ) -> Self {
        .init(
            maxContextBytes: override.maxContextBytes ?? maxContextBytes,
            maxContextTokens: override.maxContextTokens ?? maxContextTokens,
            maxFiles: override.maxFiles ?? maxFiles,
            maxLinesPerFile: override.maxLinesPerFile ?? maxLinesPerFile,
            maxLargestSourceTokens: override.maxLargestSourceTokens ?? maxLargestSourceTokens
        )
    }
}

public struct RuntimeExecutionLimits: Sendable, Codable, Hashable {
    public var maxRuntimeSeconds: TimeInterval?
    public var maxIterations: Int?

    public init(
        maxRuntimeSeconds: TimeInterval? = nil,
        maxIterations: Int? = nil
    ) {
        self.maxRuntimeSeconds = maxRuntimeSeconds
        self.maxIterations = maxIterations
    }

    public static let unlimited = Self()
}

public extension RuntimeExecutionLimits {
    var isUnlimited: Bool {
        maxRuntimeSeconds == nil
            && maxIterations == nil
    }

    func merged(
        with override: Self
    ) -> Self {
        .init(
            maxRuntimeSeconds: override.maxRuntimeSeconds ?? maxRuntimeSeconds,
            maxIterations: override.maxIterations ?? maxIterations
        )
    }
}

public struct ExecutionLimits: Sendable, Codable, Hashable {
    public var paths: PathExecutionLimits
    public var reads: ReadExecutionLimits
    public var writes: WriteExecutionLimits
    public var context: ContextExecutionLimits
    public var runtime: RuntimeExecutionLimits

    public var maxTargetPathCount: Int?
    public var maxWriteCount: Int?
    public var maxBytes: Int?
    public var maxRuntimeSeconds: TimeInterval?

    public init(
        paths: PathExecutionLimits = .unlimited,
        reads: ReadExecutionLimits = .unlimited,
        writes: WriteExecutionLimits = .unlimited,
        context: ContextExecutionLimits = .unlimited,
        runtime: RuntimeExecutionLimits = .unlimited,
        maxTargetPathCount: Int? = nil,
        maxWriteCount: Int? = nil,
        maxBytes: Int? = nil,
        maxRuntimeSeconds: TimeInterval? = nil
    ) {
        self.paths = paths
        self.reads = reads
        self.writes = writes
        self.context = context
        self.runtime = runtime
        self.maxTargetPathCount = maxTargetPathCount
        self.maxWriteCount = maxWriteCount
        self.maxBytes = maxBytes
        self.maxRuntimeSeconds = maxRuntimeSeconds
    }

    public static let unlimited = Self()
}

public extension ExecutionLimits {
    var isUnlimited: Bool {
        paths.isUnlimited
            && reads.isUnlimited
            && writes.isUnlimited
            && context.isUnlimited
            && runtime.isUnlimited
            && maxTargetPathCount == nil
            && maxWriteCount == nil
            && maxBytes == nil
            && maxRuntimeSeconds == nil
    }

    func merged(
        with override: ExecutionLimits?
    ) -> ExecutionLimits {
        guard let override else {
            return self
        }

        return .init(
            paths: paths.merged(
                with: override.paths
            ),
            reads: reads.merged(
                with: override.reads
            ),
            writes: writes.merged(
                with: override.writes
            ),
            context: context.merged(
                with: override.context
            ),
            runtime: runtime.merged(
                with: override.runtime
            ),
            maxTargetPathCount: override.maxTargetPathCount ?? maxTargetPathCount,
            maxWriteCount: override.maxWriteCount ?? maxWriteCount,
            maxBytes: override.maxBytes ?? maxBytes,
            maxRuntimeSeconds: override.maxRuntimeSeconds ?? maxRuntimeSeconds
        )
    }

    func requiresHumanReview(
        for preflight: ToolPreflight
    ) -> Bool {
        legacyRequiresHumanReview(
            for: preflight
        ) || pathRequiresHumanReview(
            for: preflight
        ) || readRequiresHumanReview(
            for: preflight
        ) || writeRequiresHumanReview(
            for: preflight
        ) || contextRequiresHumanReview(
            for: preflight
        ) || runtimeRequiresHumanReview(
            for: preflight
        )
    }
}

private extension ExecutionLimits {
    func legacyRequiresHumanReview(
        for preflight: ToolPreflight
    ) -> Bool {
        if let maxTargetPathCount,
           preflight.targetPaths.count > maxTargetPathCount {
            return true
        }

        if let maxWriteCount,
           preflight.estimatedWriteCount > maxWriteCount {
            return true
        }

        if let maxBytes,
           let maximumEstimatedByteCount = preflight.maximumEstimatedByteCount,
           maximumEstimatedByteCount > maxBytes {
            return true
        }

        if let maxRuntimeSeconds,
           let estimatedRuntimeSeconds = preflight.estimatedRuntimeSeconds,
           estimatedRuntimeSeconds > maxRuntimeSeconds {
            return true
        }

        return false
    }

    func pathRequiresHumanReview(
        for preflight: ToolPreflight
    ) -> Bool {
        if let maxTargetPathCount = paths.maxTargetPathCount,
           preflight.targetPaths.count > maxTargetPathCount {
            return true
        }

        if let maxScanEntries = paths.maxScanEntries,
           let estimatedScanEntries = preflight.estimatedScanEntries,
           estimatedScanEntries > maxScanEntries {
            return true
        }

        if let maxScanDepth = paths.maxScanDepth,
           let estimatedScanDepth = preflight.estimatedScanDepth,
           estimatedScanDepth > maxScanDepth {
            return true
        }

        if paths.allowHidden == false,
           preflight.includesHiddenPaths {
            return true
        }

        if paths.allowSymlinks == false,
           preflight.followsSymlinks {
            return true
        }

        if let maxRootsPerToolCall = paths.maxRootsPerToolCall,
           preflight.rootIDs.count > maxRootsPerToolCall {
            return true
        }

        return false
    }

    func readRequiresHumanReview(
        for preflight: ToolPreflight
    ) -> Bool {
        if let maxReadBytes = reads.maxReadBytes,
           let estimatedReadBytes = preflight.estimatedReadBytes,
           estimatedReadBytes > maxReadBytes {
            return true
        }

        if let maxReadLines = reads.maxReadLines,
           let estimatedReadLines = preflight.estimatedReadLines,
           estimatedReadLines > maxReadLines {
            return true
        }

        if let maxFilesPerRead = reads.maxFilesPerRead,
           let estimatedFileReadCount = preflight.estimatedFileReadCount,
           estimatedFileReadCount > maxFilesPerRead {
            return true
        }

        if let maxToolOutputBytes = reads.maxToolOutputBytes,
           let estimatedToolOutputBytes = preflight.estimatedToolOutputBytes,
           estimatedToolOutputBytes > maxToolOutputBytes {
            return true
        }

        return false
    }

    func writeRequiresHumanReview(
        for preflight: ToolPreflight
    ) -> Bool {
        if let maxWriteCount = writes.maxWriteCount,
           preflight.estimatedWriteCount > maxWriteCount {
            return true
        }

        if let maxWriteBytes = writes.maxWriteBytes,
           let estimatedWriteBytes = preflight.estimatedWriteBytes,
           estimatedWriteBytes > maxWriteBytes {
            return true
        }

        if let maxChangedLineCount = writes.maxChangedLineCount,
           let estimatedChangedLineCount = preflight.estimatedChangedLineCount,
           estimatedChangedLineCount > maxChangedLineCount {
            return true
        }

        if writes.requirePreviewForWrites == true,
           preflight.estimatedWriteCount > 0,
           !preflight.isPreview {
            return true
        }

        return false
    }

    func contextRequiresHumanReview(
        for preflight: ToolPreflight
    ) -> Bool {
        if let maxContextBytes = context.maxContextBytes,
           let estimatedContextBytes = preflight.estimatedContextBytes,
           estimatedContextBytes > maxContextBytes {
            return true
        }

        if let maxContextTokens = context.maxContextTokens,
           let estimatedContextTokens = preflight.estimatedContextTokens,
           estimatedContextTokens > maxContextTokens {
            return true
        }

        if let maxFiles = context.maxFiles,
           let estimatedContextFiles = preflight.estimatedContextFiles,
           estimatedContextFiles > maxFiles {
            return true
        }

        if let maxLinesPerFile = context.maxLinesPerFile,
           let estimatedReadLines = preflight.estimatedReadLines,
           estimatedReadLines > maxLinesPerFile {
            return true
        }

        if let maxLargestSourceTokens = context.maxLargestSourceTokens,
           let estimatedLargestSourceTokens = preflight.estimatedLargestSourceTokens,
           estimatedLargestSourceTokens > maxLargestSourceTokens {
            return true
        }

        return false
    }

    func runtimeRequiresHumanReview(
        for preflight: ToolPreflight
    ) -> Bool {
        if let maxRuntimeSeconds = runtime.maxRuntimeSeconds,
           let estimatedRuntimeSeconds = preflight.estimatedRuntimeSeconds,
           estimatedRuntimeSeconds > maxRuntimeSeconds {
            return true
        }

        return false
    }
}
