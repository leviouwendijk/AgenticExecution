extension ToolRegistry {
    /// Install capabilities derived from the completed declared registry.
    ///
    /// This remains internal to AgenticExecution so callers use the canonical
    /// `Agentic.tool.registry(...)` construction surface rather than manually
    /// finalizing or enriching registries.
    mutating func installIntrinsicTools() throws {
        let inspection = inspect()

        try register(
            InspectToolRegistryTool(
                inspection: inspection
            )
        )
    }
}
