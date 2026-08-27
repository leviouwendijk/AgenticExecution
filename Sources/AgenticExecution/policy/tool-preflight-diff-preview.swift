import Difference
import Foundation

public struct ToolPreflightDiffPreview: Sendable, Codable, Hashable {
    public let title: String?
    public let format: String
    public let contextLineCount: Int
    public let text: String
    public let layout: DifferenceLayout?
    public let insertedLineCount: Int
    public let deletedLineCount: Int

    public init(
        title: String? = nil,
        format: String = "difference.unified",
        contextLineCount: Int = 3,
        text: String,
        layout: DifferenceLayout? = nil,
        insertedLineCount: Int = 0,
        deletedLineCount: Int = 0
    ) {
        self.title = title
        self.format = format
        self.contextLineCount = max(
            0,
            contextLineCount
        )
        self.text = text
        self.layout = layout
        self.insertedLineCount = max(
            0,
            insertedLineCount
        )
        self.deletedLineCount = max(
            0,
            deletedLineCount
        )
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty && (layout?.isEmpty ?? true)
    }

    public var changedLineCount: Int {
        insertedLineCount + deletedLineCount
    }
}
