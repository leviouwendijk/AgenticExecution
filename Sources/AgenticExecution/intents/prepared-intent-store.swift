import Agentic

public protocol PreparedIntentStore: Sendable {
    func load(
        id: PreparedIntentIdentifier
    ) async throws -> PreparedIntent?

    func list() async throws -> [PreparedIntent]

    func save(
        _ intent: PreparedIntent
    ) async throws

    func delete(
        id: PreparedIntentIdentifier
    ) async throws
}
