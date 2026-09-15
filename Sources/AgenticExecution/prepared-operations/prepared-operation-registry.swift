import Foundation

public enum PreparedOperationRegistryError:
    Error,
    Sendable,
    Hashable,
    LocalizedError
{
    case duplicateSchema(
        PreparedOperation.Schema
    )
    case unregisteredSchema(
        PreparedOperation.Schema
    )

    public var errorDescription: String? {
        switch self {
        case .duplicateSchema(let schema):
            return "Prepared operation schema '\(schema.identifier.rawValue)' version \(schema.version.string(prefixStyle: .none)) is already registered."

        case .unregisteredSchema(let schema):
            return "Prepared operation schema '\(schema.identifier.rawValue)' version \(schema.version.string(prefixStyle: .none)) is not registered."
        }
    }
}

public struct PreparedOperationRegistry: Sendable {
    private struct Registration: Sendable {
        let schema: PreparedOperation.Schema
        let execute: @Sendable (
            PreparedOperation.Envelope,
            PreparedOperation.Context
        ) async throws -> PreparedOperation.ResultEnvelope
    }

    private var registrations:
        [PreparedOperation.Schema: Registration]

    public init() {
        self.registrations = [:]
    }

    public var schemas: [PreparedOperation.Schema] {
        registrations.keys.sorted { lhs, rhs in
            if lhs.identifier.rawValue == rhs.identifier.rawValue {
                return lhs.version < rhs.version
            }

            return lhs.identifier.rawValue < rhs.identifier.rawValue
        }
    }

    public var count: Int {
        registrations.count
    }

    public mutating func register<Operation>(
        _ operation: Operation
    ) throws where Operation: AgentPreparedOperation {
        let schema = Operation.schema

        guard registrations[schema] == nil else {
            throw PreparedOperationRegistryError.duplicateSchema(
                schema
            )
        }

        registrations[schema] = Registration(
            schema: schema,
            execute: { envelope, context in
                let plan = try Operation.plan(
                    from: envelope
                )
                let result = try await operation.execute(
                    plan,
                    context: context
                )

                return try Operation.resultEnvelope(
                    result
                )
            }
        )
    }

    public func contains(
        _ schema: PreparedOperation.Schema
    ) -> Bool {
        registrations[schema] != nil
    }

    public func execute(
        _ envelope: PreparedOperation.Envelope,
        context: PreparedOperation.Context = .init()
    ) async throws -> PreparedOperation.ResultEnvelope {
        guard let registration = registrations[envelope.schema] else {
            throw PreparedOperationRegistryError.unregisteredSchema(
                envelope.schema
            )
        }

        return try await registration.execute(
            envelope,
            context
        )
    }
}
