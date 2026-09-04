/// Configuration applied when Agentic constructs a complete tool registry.
///
/// A bare `ToolRegistry()` remains unconfigured and contains only explicitly
/// registered tools. `Agentic.tool.registry(...)` applies this configuration
/// after declarations have been materialized.
public struct ToolRegistryConfiguration:
    Sendable,
    Hashable
{
    /// Whether registry-owned intrinsic capabilities are installed.
    ///
    /// This is a bootstrap-time hard opt-out. Dynamic model visibility belongs
    /// to the tool-exposure layer and can change without rebuilding the registry.
    public var includeIntrinsicTools: Bool

    public init(
        includeIntrinsicTools: Bool = true
    ) {
        self.includeIntrinsicTools =
            includeIntrinsicTools
    }

    public static let `default` = Self()
}
