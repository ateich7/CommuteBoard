import Foundation

/// A minimal Protocol Buffers wire-format reader.
///
/// The MTA subway feed is protobuf, not JSON. Rather than pull in SwiftProtobuf and
/// generated code for the whole GTFS-Realtime schema, this walks the raw
/// (field number, value) pairs and lets the caller pick out the few fields it needs.
/// Wire format reference: https://protobuf.dev/programming-guides/encoding/
struct ProtobufReader {
    enum Value {
        case varint(UInt64)
        case bytes(ArraySlice<UInt8>)   // strings and nested messages
        case fixed64, fixed32           // skipped; GTFS-Realtime doesn't use these for our fields

        var string: String? {
            if case .bytes(let bytes) = self { return String(decoding: bytes, as: UTF8.self) }
            return nil
        }
    }

    enum DecodeError: Error {
        case truncated
        case malformedVarint
        case unsupportedWireType(UInt64)
    }

    private let bytes: ArraySlice<UInt8>
    private var position: Int

    init(_ data: Data) {
        self.init(ArraySlice([UInt8](data)))
    }

    init(_ bytes: ArraySlice<UInt8>) {
        self.bytes = bytes
        self.position = bytes.startIndex
    }

    /// Returns the next field in this message, or nil at the end.
    mutating func next() throws -> (field: Int, value: Value)? {
        guard position < bytes.endIndex else { return nil }

        let key = try readVarint()
        let field = Int(key >> 3)

        switch key & 0x7 {
        case 0:
            return (field, .varint(try readVarint()))
        case 1:
            try skip(8)
            return (field, .fixed64)
        case 2:
            let length = try readVarint()
            guard length <= UInt64(bytes.endIndex - position) else { throw DecodeError.truncated }
            let end = position + Int(length)
            let slice = bytes[position..<end]
            position = end
            return (field, .bytes(slice))
        case 5:
            try skip(4)
            return (field, .fixed32)
        case let wireType:
            throw DecodeError.unsupportedWireType(wireType)
        }
    }

    private mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard position < bytes.endIndex else { throw DecodeError.truncated }
            let byte = bytes[position]
            position += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            guard shift < 64 else { throw DecodeError.malformedVarint }
        }
    }

    private mutating func skip(_ count: Int) throws {
        guard bytes.endIndex - position >= count else { throw DecodeError.truncated }
        position += count
    }
}
