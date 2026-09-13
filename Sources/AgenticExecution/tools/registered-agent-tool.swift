import Agentic
import AgenticRecovery
import Foundation
import Primitives

/// Registry-facing executable representation of one typed AgentTool.
///
/// Registration captures every operation that requires the concrete Self/Input/Output
/// types. The registry never needs to reopen an AgentTool existential afterward.
public struct RegisteredAgentTool: Sendable {
    public enum Reconciliation: Sendable {
        case applied(AgentToolResult)
        case applied_without_output
        case not_applied
        case unknown

        public var state: Recovery.State {
            switch self {
            case .applied,
                 .applied_without_output:
                .init(
                    reconciled: .applied
                )

            case .not_applied:
                .init(
                    reconciled: .not_applied
                )

            case .unknown:
                .init(
                    reconciled: .unknown
                )
            }
        }
    }

    private enum ReconciliationExecution: Sendable {
        case applied(
            output: JSONValue,
            projection: AgentToolResultProjection?
        )
        case applied_without_output
        case not_applied
        case unknown
    }

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

    private let reconcileHandler:
        @Sendable (
            AgentToolCall,
            AgentToolCallFailure,
            AgentToolExecutionContext
        ) async throws -> ReconciliationExecution?

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
                    tool: tool,
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
                    tool: tool,
                    call: call,
                    phase: .decode,
                    context: context,
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
                    tool: tool,
                    call: call,
                    phase: .preflight,
                    input: input,
                    context: context,
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
                    tool: tool,
                    call: call,
                    phase: .decode,
                    context: context,
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
                    tool: tool,
                    call: call,
                    phase: .call,
                    input: input,
                    context: context,
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
                    tool: tool,
                    call: call,
                    phase: .process,
                    input: input,
                    context: context,
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
                    tool: tool,
                    call: call,
                    phase: .encode,
                    input: input,
                    context: context,
                    error: error
                )
            }

            return (
                output: encodedOutput,
                projection: projection,
                isError: isError
            )
        }

        self.reconcileHandler = { call, failure, context in
            let input: T.Input

            do {
                input = try JSONToolBridge.decode(
                    T.Input.self,
                    from: call.input
                )
            } catch {
                throw phasedToolCallError(
                    tool: tool,
                    call: call,
                    phase: .decode,
                    context: context,
                    error: error
                )
            }

            guard let reconciliation = try await tool.reconcile(
                input,
                after: failure,
                context: context
            ) else {
                return nil
            }

            switch reconciliation {
            case .applied(let output):
                let projection: AgentToolResultProjection?

                do {
                    projection = try tool.process(
                        output,
                        input: input,
                        context: context
                    )
                } catch {
                    throw phasedToolCallError(
                        tool: tool,
                        call: call,
                        phase: .process,
                        input: input,
                        context: context,
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
                        tool: tool,
                        call: call,
                        phase: .encode,
                        input: input,
                        context: context,
                        error: error
                    )
                }

                return .applied(
                    output: encodedOutput,
                    projection: projection
                )

            case .applied_without_output:
                return .applied_without_output

            case .not_applied:
                return .not_applied

            case .unknown:
                return .unknown
            }
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

    public func reconcile(
        _ call: AgentToolCall,
        failure: AgentToolCallFailure,
        context: AgentToolExecutionContext
    ) async throws -> Reconciliation? {
        guard
            failure.tool == capability.definition.identifier,
            failure.toolCallID == call.id,
            failure.phase == .call
        else {
            throw RegisteredAgentToolError.invalidFailure(
                tool: capability.definition.name,
                callID: call.id
            )
        }

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

        guard let reconciliation = try await reconcileHandler(
            call,
            failure,
            executionContext
        ) else {
            return nil
        }

        switch reconciliation {
        case .applied(let output, let projection):
            let processing = AgentToolResultProcessing(
                projection: projection,
                observations: await recorder.snapshot()
            )

            return .applied(
                AgentToolResult(
                    toolCallID: call.id,
                    name: capability.definition.name,
                    output: output,
                    processing:
                        processing.isEmpty
                            ? nil
                            : processing,
                    isError: false
                )
            )

        case .applied_without_output:
            return .applied_without_output

        case .not_applied:
            return .not_applied

        case .unknown:
            return .unknown
        }
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

    case invalidFailure(
        tool: String,
        callID: String
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

        case .invalidFailure(
            let tool,
            let callID
        ):
            "Cannot reconcile tool '\(tool)' for call '\(callID)' from an unrelated or non-call failure."
        }
    }
}

private func recoveryIncidentCapturingEvidence(
    _ incident: Recovery.Incident,
    error: any Error
) -> Recovery.Incident {
    guard incident.report == nil else {
        return incident
    }

    return Recovery.Incident(
        capturing: error,
        kind: incident.kind,
        stage: incident.stage,
        effectState: incident.effectState,
        retrySafety: incident.retrySafety,
        scope: incident.scope,
        message: incident.message,
        metadata: incident.metadata
    )
}

private func phasedToolCallError<T: AgentTool>(
    tool: T,
    call: AgentToolCall,
    phase: AgentToolCallPhase,
    input: T.Input? = nil,
    context: AgentToolExecutionContext = .init(),
    error: any Error
) -> AgentToolCallError {
    if let error = error as? AgentToolCallError {
        return error
    }

    let classifiedIncident = tool.classify(
        error,
        phase: phase,
        input: input,
        context: context.withToolCallID(
            call.id
        )
    )
    let incident = classifiedIncident.map {
        recoveryIncidentCapturingEvidence(
            $0,
            error: error
        )
    }

    return AgentToolCallError(
        tool: tool.identifier,
        toolCallID: call.id,
        phase: phase,
        underlying: error,
        incident: incident
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
