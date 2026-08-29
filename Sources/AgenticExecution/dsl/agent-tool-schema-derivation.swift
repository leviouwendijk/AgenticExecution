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
