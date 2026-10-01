import Agentic
import AgenticExecution
import Foundation
import Primitives
import Schema
import TestFlows
import Workspace

extension AgenticExecutionFlowTesting {
    static func runExecutionObservations() async throws -> [TestDiagnostic] {
        let registry = try ToolRegistry { ObservationFixtureTool() }
        let invoker = ToolInvoker(
            registry: registry,
            policy: .init(autonomyMode: .auto_observe)
        )
        func call(_ value: String) throws -> ToolCall {
            .init(
                id: value,
                tool: ObservationFixtureTool.definition.identifier,
                input: try JSONToolBridge.encode(ObservationFixtureValue(value: value))
            )
        }
        let firstCall = try call("first")
        let secondCall = try call("second")
        async let first = invoker.invoke(firstCall)
        async let second = invoker.invoke(secondCall)
        let pair = try await (first, second)
        for (invocation, expected) in [(pair.0, "first"), (pair.1, "second")] {
            let execution = try Expect.notNil(invocation.execution, "execution exists")
            try Expect.equal(execution.observations.map(\.content), [expected, ""], "concurrent observations stay scoped and ordered")
            try Expect.equal(execution.observations.first?.origin?.toolCallID, expected, "observations retain call identity")
            let decoded = try JSONDecoder().decode(ToolExecutionResult.self, from: JSONEncoder().encode(execution))
            try Expect.equal(decoded, execution, "execution observations survive persistence")
        }
        let failed = try await invoker.invoke(call("fail"))
        let failure = try Expect.notNil(failed.execution, "failure produces execution evidence")
        try Expect.equal(failure.result.isError, true, "fixture throws after output")
        try Expect.equal(failure.observations.map(\.content), ["fail", ""], "throwing preserves preceding observations")
        let direct = try await registry.execute(call("direct"))
        try Expect.equal(direct.observations.map(\.content), ["direct", ""], "direct registry execution captures observations")
        let legacy = LegacyObservationExecution(result: direct.result)
        let decoded = try JSONDecoder().decode(ToolExecutionResult.self, from: JSONEncoder().encode(legacy))
        try Expect.equal(decoded.observations, [], "older execution records decode without observations")
        return [.field("observations", "concurrency, failure, direct execution, persistence")]
    }
}

private struct LegacyObservationExecution: Encodable {
    let result: ToolResult
}

private struct ObservationFixtureValue: Sendable, Codable, Hashable, JSONSchemaProviding {
    let value: String
    static var jsonschema: JSONSchema { .any }
}

private struct ObservationFixtureTool: Tool {
    typealias Input = ObservationFixtureValue
    typealias Output = ObservationFixtureValue
    static let definition = ToolDefinition(
        identifier: "execution_observation_fixture",
        purpose: "Exercise invocation-local execution evidence.",
        risk: .observe
    )

    let barrier = ObservationFixtureBarrier()

    func call(_ input: Input, workspace _: WorkspaceContext?) async throws -> Output {
        if input.value == "first" || input.value == "second" {
            await barrier.arrive()
        }
        await ToolExecutionObservations.emit(.init(kind: .standard_output, content: input.value))
        await Task.yield()
        await ToolExecutionObservations.emit(.init(kind: .standard_error, content: ""))
        if input.value == "fail" { throw Failure.expected }
        return input
    }

    private enum Failure: Error { case expected }
}

private actor ObservationFixtureBarrier {
    var waiting: CheckedContinuation<Void, Never>?

    func arrive() async {
        if let waiting {
            self.waiting = nil
            waiting.resume()
        } else {
            await withCheckedContinuation { waiting = $0 }
        }
    }
}
