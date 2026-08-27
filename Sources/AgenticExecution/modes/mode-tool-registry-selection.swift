import Agentic

public extension ToolRegistry {
    func selecting(
        _ identifiers: [AgentToolIdentifier]
    ) throws -> ToolRegistry {
        var selected = ToolRegistry()
        var seen = Set<AgentToolIdentifier>()

        for identifier in identifiers {
            guard seen.insert(identifier).inserted else {
                continue
            }

            guard let tool = tool(
                identifiedBy: identifier
            ) else {
                throw ModeApplicationError.missingTool(
                    identifier.rawValue
                )
            }

            try selected.register(
                tool
            )
        }

        return selected
    }
}
