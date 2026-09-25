import Agentic
import Foundation
import Primitives
import Schema
import Workspace

/// Registry-facing executable representation of one canonical typed Tool.
///
/// Registration captures every operation that requires the concrete
/// Self/Input/Output types. The registry never needs to reopen a Tool
/// existential afterward.
public struct RegisteredAgentTool: Sendable {
    public enum Reconciliation: Sendable {
        case applied(ToolExecutionResult)
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
            projection: ToolCall.ResultProjection?
        )
        case applied_without_output
        case not_applied
        case unknown
    }

    public let capability: AgentToolCapability

    private let parseModelInputHandler:
        @Sendable (ToolCall) throws -> Void

    private let preflightHandler:
        @Sendable (
            ToolCall,
            WorkspaceContext?
        ) async throws -> ToolPreflight

    private let callHandler:
        @Sendable (
            ToolCall,
            WorkspaceContext?
        ) async throws -> (
            output: JSONValue,
            projection: ToolCall.ResultProjection?,
            isError: Bool
        )

    private let reconcileHandler:
        @Sendable (
            ToolCall,
            ToolCall.Failure,
            WorkspaceContext?
        ) async throws -> ReconciliationExecution?

    public init<T>(
        _ tool: T,
        modelContract: AgentToolModelContract? = nil,
        execution: AgentToolExecutionContract = .fixed
    ) where T: Tool {
        let semanticInputSchema = T.Input.jsonschema
        let resolvedModelContract =
            modelContract
                ?? .modelFacing(
                    inputSchema: semanticInputSchema
                )

        let capability = AgentToolCapability(
            definition: .init(
                identifier: T.definition.identifier,
                description: T.definition.purpose,
                inputSchema:
                    resolvedModelContract
                        .semanticInputSchema?
                        .jsonvalue,
                risk: T.definition.risk
            ),
            modelContract: resolvedModelContract,
            execution: execution
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

        self.preflightHandler = { call, workspace in
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
                    error: error
                )
            }

            let preflight: ToolPreflight

            do {
                preflight = try await tool.preflight(
                    input,
                    workspace: workspace
                )
            } catch {
                throw phasedToolCallError(
                    tool: tool,
                    call: call,
                    phase: .preflight,
                    input: input,
                    error: error
                )
            }

            return preflight
        }

        self.callHandler = { call, workspace in
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
                    error: error
                )
            }

            let output: T.Output
            let isError: Bool

            do {
                output = try await tool.call(
                    input,
                    workspace: workspace
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
                    error: error
                )
            }

            let projection: ToolCall.ResultProjection?

            do {
                projection = try tool.process(
                    output,
                    input: input
                )
            } catch {
                throw phasedToolCallError(
                    tool: tool,
                    call: call,
                    phase: .process,
                    input: input,
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
                    error: error
                )
            }

            return (
                output: encodedOutput,
                projection: projection,
                isError: isError
            )
        }

        self.reconcileHandler = { call, failure, workspace in
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
                    error: error
                )
            }

            guard let reconciliation = try await tool.reconcile(
                input,
                after: failure,
                workspace: workspace
            ) else {
                return nil
            }

            switch reconciliation {
            case .applied(let output):
                let projection: ToolCall.ResultProjection?

                do {
                    projection = try tool.process(
                        output,
                        input: input
                    )
                } catch {
                    throw phasedToolCallError(
                        tool: tool,
                        call: call,
                        phase: .process,
                        input: input,
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
        _ call: ToolCall
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
        _ call: ToolCall,
        workspace: WorkspaceContext? = nil
    ) async throws -> ToolPreflight {
        try await preflightHandler(
            call,
            workspace
        )
    }

    public func execute(
        _ call: ToolCall,
        workspace: WorkspaceContext? = nil
    ) async throws -> ToolExecutionResult {
        let execution = try await callHandler(
            call,
            workspace
        )

        return ToolExecutionResult(
            result: ToolResult(
                toolCallID: call.id,
                tool: capability.definition.identifier,
                output: execution.output,
                projection: execution.projection,
                isError: execution.isError
            )
        )
    }

    public func reconcile(
        _ call: ToolCall,
        failure: ToolCall.Failure,
        workspace: WorkspaceContext? = nil
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

        guard let reconciliation = try await reconcileHandler(
            call,
            failure,
            workspace
        ) else {
            return nil
        }

        switch reconciliation {
        case .applied(let output, let projection):
            return .applied(
                ToolExecutionResult(
                    result: ToolResult(
                        toolCallID: call.id,
                        tool: capability.definition.identifier,
                        output: output,
                        projection: projection,
                        isError: false
                    )
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
    public let call: ToolCall
    public let capability: AgentToolCapability

    fileprivate init(
        call: ToolCall,
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

private func phasedToolCallError<T: Tool>(
    tool: T,
    call: ToolCall,
    phase: ToolCall.Phase,
    input: T.Input? = nil,
    error: any Error
) -> ToolCall.Error {
    if let error = error as? ToolCall.Error {
        return error
    }

    let classifiedIncident = tool.classify(
        error,
        phase: phase,
        input: input
    )
    let incident = classifiedIncident.map {
        recoveryIncidentCapturingEvidence(
            $0,
            error: error
        )
    }

    return ToolCall.Error(
        tool: T.definition.identifier,
        toolCallID: call.id,
        phase: phase,
        underlying: error,
        incident: incident
    )
}
