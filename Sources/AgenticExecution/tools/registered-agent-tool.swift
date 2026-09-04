import Agentic
import Foundation
import Primitives

/// Registry-facing executable representation of one typed AgentTool.
///
/// Registration captures every operation that requires the concrete Self/Input/Output
/// types. The registry never needs to reopen an AgentTool existential afterward.
public struct RegisteredAgentTool: Sendable {
    public let capability: AgentToolCapability

    private let parseModelInputHandler:
        @Sendable (AgentToolCall) throws -> Void

    private let preflightHandler:
        @Sendable (
            AgentToolCall,
            AgentToolExecutionContext
        ) async throws -> ToolPreflight

    private let callHandler:
        @Sendable (
            AgentToolCall,
            AgentToolExecutionContext
        ) async throws -> (
            output: JSONValue,
            projection: AgentToolResultProjection?,
            isError: Bool
        )

    public init<T>(
        _ tool: T
    ) where T: AgentTool {
        let capability = AgentToolCapability(
            definition: tool.definition,
            modelContract: tool.modelContract,
            execution: tool.execution
        )

        self.capability = capability

        self.parseModelInputHandler = { call in
            do {
                _ = try JSONToolBridge.decode(
                    T.Input.self,
                    from: call.input
                )
            } catch {
                throw phasedToolCallError(
                    tool: tool.identifier,
                    call: call,
                    phase: .decode,
                    error: error
                )
            }
        }

        self.preflightHandler = { call, context in
            let input: T.Input

            do {
                input = try JSONToolBridge.decode(
                    T.Input.self,
                    from: call.input
                )
            } catch {
                throw phasedToolCallError(
                    tool: tool.identifier,
                    call: call,
                    phase: .decode,
                    error: error
                )
            }

            do {
                return try await tool.preflight(
                    input,
                    context: context
                )
            } catch {
                throw phasedToolCallError(
                    tool: tool.identifier,
                    call: call,
                    phase: .preflight,
                    error: error
                )
            }
        }

        self.callHandler = { call, context in
            let input: T.Input

            do {
                input = try JSONToolBridge.decode(
                    T.Input.self,
                    from: call.input
                )
            } catch {
                throw phasedToolCallError(
                    tool: tool.identifier,
                    call: call,
                    phase: .decode,
                    error: error
                )
            }

            let output: T.Output
            let isError: Bool

            do {
                output = try await tool.call(
                    input,
                    context: context
                )
                isError = false
            } catch let failure as AgentToolReportedFailure<T.Output> {
                output = failure.output
                isError = true
            } catch {
                throw phasedToolCallError(
                    tool: tool.identifier,
                    call: call,
                    phase: .call,
                    error: error
                )
            }

            let projection: AgentToolResultProjection?

            do {
                projection = try tool.process(
                    output,
                    input: input,
                    context: context
                )
            } catch {
                throw phasedToolCallError(
                    tool: tool.identifier,
                    call: call,
                    phase: .process,
                    error: error
                )
            }

            let encodedOutput: JSONValue

            do {
                encodedOutput = try JSONToolBridge.encode(
                    output
                )
            } catch {
                throw phasedToolCallError(
                    tool: tool.identifier,
                    call: call,
                    phase: .encode,
                    error: error
                )
            }

            return (
                output: encodedOutput,
                projection: projection,
                isError: isError
            )
        }
    }

    public func parseModelCall(
        _ call: AgentToolCall
    ) throws -> ParsedAgentToolCall {
        guard capability.isModelFacing else {
            throw RegisteredAgentToolError.hostOnly(
                capability.definition.name
            )
        }

        try parseModelInputHandler(
            call
        )

        return ParsedAgentToolCall(
            call: call,
            capability: capability
        )
    }

    public func preflight(
        _ call: AgentToolCall,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try await preflightHandler(
            call,
            context.withToolCallID(
                call.id
            )
        )
    }

    public func execute(
        _ call: AgentToolCall,
        context: AgentToolExecutionContext
    ) async throws -> AgentToolResult {
        let recorder = AgentToolObservationRecorder()
        let upstreamSink = context.observationSink
        let observationSink = AgentToolObservationSink { observation in
            await recorder.append(
                observation
            )
            await upstreamSink?.observe(
                observation
            )
        }
        let executionContext = context
            .withToolCallID(
                call.id
            )
            .withObservationSink(
                observationSink
            )

        let execution = try await callHandler(
            call,
            executionContext
        )
        let processing = AgentToolResultProcessing(
            projection: execution.projection,
            observations: await recorder.snapshot()
        )

        return AgentToolResult(
            toolCallID: call.id,
            name: capability.definition.name,
            output: execution.output,
            processing:
                processing.isEmpty
                    ? nil
                    : processing,
            isError: execution.isError
        )
    }
}

/// A model call that has resolved to one exact registered tool and crossed that
/// tool's captured typed input parser.
public struct ParsedAgentToolCall: Sendable {
    public let call: AgentToolCall
    public let capability: AgentToolCapability

    fileprivate init(
        call: AgentToolCall,
        capability: AgentToolCapability
    ) {
        self.call = call
        self.capability = capability
    }
}

public enum RegisteredAgentToolError:
    Error,
    Sendable,
    LocalizedError
{
    case hostOnly(String)

    case invalidModelCall(
        tool: String,
        reason: String
    )

    public var errorDescription: String? {
        switch self {
        case .hostOnly(let tool):
            "Registered tool '\(tool)' is host-only and cannot be invoked by a model."

        case .invalidModelCall(
            let tool,
            let reason
        ):
            "Cannot parse model input for registered tool '\(tool)': \(reason)"
        }
    }
}

private func phasedToolCallError(
    tool: AgentToolIdentifier,
    call: AgentToolCall,
    phase: AgentToolCallPhase,
    error: any Error
) -> AgentToolCallError {
    if let error = error as? AgentToolCallError {
        return error
    }

    return AgentToolCallError(
        tool: tool,
        toolCallID: call.id,
        phase: phase,
        underlying: error
    )
}

private actor AgentToolObservationRecorder {
    private var observations:
        [AgentToolResultObservation] = []

    func append(
        _ observation: AgentToolResultObservation
    ) {
        observations.append(
            observation
        )
    }

    func snapshot() -> [AgentToolResultObservation] {
        observations
    }
}
