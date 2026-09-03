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
        @Sendable (JSONValue) throws -> Void

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
            projection: AgentToolResultProjection?
        )

    public init<T>(
        _ tool: T
    ) where T: AgentTool {
        let capability = AgentToolCapability(
            definition: tool.definition,
            modelContract: tool.modelContract,
            supportsWorkspaceTargeting:
                tool is any WorkspaceTargetableTool
        )

        self.capability = capability

        self.parseModelInputHandler = { value in
            _ = try JSONToolBridge.decode(
                T.Input.self,
                from: value
            )
        }

        self.preflightHandler = { call, context in
            let input = try JSONToolBridge.decode(
                T.Input.self,
                from: call.input
            )

            return try await tool.preflight(
                input,
                context: context
            )
        }

        self.callHandler = { call, context in
            let input = try JSONToolBridge.decode(
                T.Input.self,
                from: call.input
            )
            let output = try await tool.call(
                input,
                context: context
            )
            let projection = tool.process(
                output,
                input: input,
                context: context
            )

            return (
                output: try JSONToolBridge.encode(
                    output
                ),
                projection: projection
            )
        }
    }

    init(
        capability: AgentToolCapability,
        parseModelInput:
            @escaping @Sendable (JSONValue) throws -> Void,
        preflight:
            @escaping @Sendable (
                AgentToolCall,
                AgentToolExecutionContext
            ) async throws -> ToolPreflight,
        call:
            @escaping @Sendable (
                AgentToolCall,
                AgentToolExecutionContext
            ) async throws -> (
                output: JSONValue,
                projection: AgentToolResultProjection?
            )
    ) {
        self.capability = capability
        self.parseModelInputHandler = parseModelInput
        self.preflightHandler = preflight
        self.callHandler = call
    }

    public func parseModelCall(
        _ call: AgentToolCall
    ) throws -> ParsedAgentToolCall {
        guard capability.isModelFacing else {
            throw RegisteredAgentToolError.hostOnly(
                capability.definition.name
            )
        }

        do {
            try parseModelInputHandler(
                call.input
            )
        } catch {
            throw RegisteredAgentToolError.invalidModelCall(
                tool: capability.definition.name,
                reason: error.localizedDescription
            )
        }

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

        let output: JSONValue
        let projection: AgentToolResultProjection?
        let isError: Bool

        do {
            let execution = try await callHandler(
                call,
                executionContext
            )
            output = execution.output
            projection = execution.projection
            isError = false
        } catch let failure as AgentToolReportedFailure {
            output = failure.output
            projection = nil
            isError = true
        }

        let processing = AgentToolResultProcessing(
            projection: projection,
            observations: await recorder.snapshot()
        )

        return AgentToolResult(
            toolCallID: call.id,
            name: capability.definition.name,
            output: output,
            processing:
                processing.isEmpty
                    ? nil
                    : processing,
            isError: isError
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
