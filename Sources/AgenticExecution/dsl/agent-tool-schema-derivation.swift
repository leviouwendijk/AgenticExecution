import Agentic
import Primitives
import Schema

func derivedAgentToolInputSchema<Input>(
    _ type: Input.Type
) -> JSONValue? {
    guard let schemaType =
        type as? any JSONSchemaProviding.Type
    else {
        return nil
    }

    return schemaType
        .jsonschema
        .jsonvalue
}

func derivedAgentToolRegistration<Input>(
    _ type: Input.Type
) -> AgentToolRegistrationDescriptor
where
    Input:
        Decodable &
        Sendable
{
    guard let schemaType =
        type as? any JSONSchemaProviding.Type
    else {
        return .hostOnly
    }

    return AgentToolRegistrationDescriptor(
        modelContract: .modelFacing(
            inputSchema:
                schemaType.jsonschema
        )
    ) { value in
        _ = try JSONToolBridge.decode(
            Input.self,
            from: value
        )

        return ParsedAgentToolInput(
            jsonValue: value
        )
    }
}
