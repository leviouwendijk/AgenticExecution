import Foundation
import Primitives

public enum JSONToolBridge {
    public static func decode<T: Decodable & Sendable>(
        _ type: T.Type,
        from value: JSONValue,
        decoder _: JSONDecoder = JSONDecoder()
    ) throws -> T {
        try value.as(type)
    }

    public static func encode<T: Encodable & Sendable>(
        _ value: T,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> JSONValue {
        try JSONValueCodec.encodeValue(
            value,
            using: encoder
        )
    }
}
