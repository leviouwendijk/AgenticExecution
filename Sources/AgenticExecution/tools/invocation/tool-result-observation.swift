import Agentic

/// Execution evidence; never part of a model-facing semantic ToolResult.
public struct ToolResultObservation: Sendable, Codable, Hashable {
    public enum Kind: String, Sendable, Codable, Hashable {
        case standard_output, standard_error, diagnostic, log, detail
    }

    public enum Operation: String, Sendable, Codable, Hashable {
        case call, reconcile
    }

    public struct Origin: Sendable, Codable, Hashable {
        public let toolCallID: String
        public let operation: Operation
        /// Ordered operation within one execution, including reconciliation.
        public let ordinal: Int
    }

    public let kind: Kind
    public let label: String?
    public let content: String
    public internal(set) var origin: Origin?

    public init(kind: Kind, label: String? = nil, content: String) {
        self.kind = kind
        self.label = label
        self.content = content
        self.origin = nil
    }
}

/// Emit explicitly from a tool or its process-output adapter. This does not
/// redirect process-global stdout/stderr. Await producers before returning.
public enum ToolExecutionObservations {
    @TaskLocal private static var current: Buffer?

    public static func emit(_ observation: ToolResultObservation) async {
        await current?.append(observation)
    }

    /// An execution owns a fresh scope. Registered operations forward their
    /// evidence to that scope even when they throw; nested executions stay isolated.
    internal static func capture<Value: Sendable>(
        callID: String? = nil,
        kind: ToolResultObservation.Operation = .call,
        operation: @Sendable () async throws -> Value
    ) async rethrows -> (Value, [ToolResultObservation]) {
        let parent = callID == nil ? nil : current
        let origin: ToolResultObservation.Origin?
        if let callID {
            let ordinal = await parent?.nextOrdinal() ?? 1
            origin = .init(toolCallID: callID, operation: kind, ordinal: ordinal)
        } else {
            origin = nil
        }
        let buffer = Buffer(origin: origin)
        do {
            let value = try await $current.withValue(buffer, operation: operation)
            let observations = await buffer.finish()
            await parent?.append(contentsOf: observations)
            return (value, observations)
        } catch {
            let observations = await buffer.finish()
            await parent?.append(contentsOf: observations)
            throw error
        }
    }

    private actor Buffer {
        let origin: ToolResultObservation.Origin?
        var observations: [ToolResultObservation] = []
        var ordinal = 0
        var finished = false

        init(origin: ToolResultObservation.Origin?) {
            self.origin = origin
        }

        func nextOrdinal() -> Int {
            ordinal += 1
            return ordinal
        }

        func append(_ observation: ToolResultObservation) {
            guard !finished else { return }
            var observation = observation
            observation.origin = origin
            observations.append(observation)
        }

        func append(contentsOf values: [ToolResultObservation]) {
            guard !finished else { return }
            observations.append(contentsOf: values)
        }

        func finish() -> [ToolResultObservation] {
            finished = true
            return observations
        }
    }
}
