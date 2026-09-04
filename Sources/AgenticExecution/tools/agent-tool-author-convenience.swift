import Schema
/// Optional shorthand for authoring strongly typed Agentic tool inputs.
///
/// Conforming to `AgentToolInput` supplies the standard input contract used by
/// Agentic tools: decodable, sendable, and schema-providing.
///
/// This protocol exists for authoring convenience only. `AgentTool` retains
/// structural requirements on its `Input` associated type, so external types do
/// not need to import AgenticExecution or conform to `AgentToolInput` when they
/// already satisfy the same underlying requirements.
public protocol AgentToolInput:
    Decodable,
    Sendable,
    JSONSchemaProviding
{}

/// Optional shorthand for authoring strongly typed Agentic tool outputs.
///
/// Conforming to `AgentToolOutput` supplies the standard output contract used by
/// Agentic tools: encodable and sendable.
///
/// This protocol exists for authoring convenience only. `AgentTool` retains
/// structural requirements on its `Output` associated type, so external types do
/// not need to conform to `AgentToolOutput` when they already satisfy the same
/// underlying requirements.
public protocol AgentToolOutput:
    Encodable,
    Sendable
{}
