import Agentic

public extension ToolRegistry {
    func selecting(
        _ identifiers: [ToolIdentifier]
    ) throws -> ToolRegistry {
        var selected = ToolRegistry()
        var seen = Set<ToolIdentifier>()

        for identifier in identifiers {
            guard seen.insert(identifier).inserted else {
                continue
            }

            guard let tool = registeredTool(
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
