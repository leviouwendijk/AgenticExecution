import Foundation

/// Couples live exposure state to immutable completed-registry metadata.
/// It never retains executable ToolRegistry authority.
public actor AgentToolExposureInspectionSource {
    public let exposure: AgentToolExposure
    private var registryInspection: AgentToolRegistryInspection?

    public init(
        exposure: AgentToolExposure
    ) {
        self.exposure = exposure
    }

    public func bind(
        registryInspection: AgentToolRegistryInspection
    ) {
        self.registryInspection = registryInspection
    }

    public func inspect()
        async throws
        -> AgentToolExposureInspection
    {
        guard let registryInspection else {
            throw AgentToolExposureInspectionSourceError.unbound
        }

        return await exposure.inspect(
            in: registryInspection
        )
    }
}

public enum AgentToolExposureInspectionSourceError:
    Error,
    Sendable,
    LocalizedError
{
    case unbound

    public var errorDescription: String? {
        "Tool exposure inspection has no completed registry inspection bound."
    }
}
