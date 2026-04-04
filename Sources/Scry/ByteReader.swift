import Foundation

struct ByteReader {
  enum ByteOrder {
    case big, little
  }

  let data: Data
  var offset: Int
  var byteOrder: ByteOrder

  init(data: Data, offset: Int = 0, byteOrder: ByteOrder = .big) {
    self.data = data
    self.offset = offset
    self.byteOrder = byteOrder
  }

  var remaining: Int {
    max(0, data.count - offset)
  }

  mutating func readUInt8() throws -> UInt8 {
    guard offset < data.count else { throw EXIFError.truncatedData }
    let value = data[data.startIndex + offset]
    offset += 1
    return value
  }

  mutating func readUInt16() throws -> UInt16 {
    guard offset + 2 <= data.count else { throw EXIFError.truncatedData }
    let start = data.startIndex + offset
    let raw = UInt16(data[start]) << 8 | UInt16(data[start + 1])
    offset += 2
    switch byteOrder {
      case .big: return raw
      case .little: return raw.byteSwapped
    }
  }

  mutating func readUInt32() throws -> UInt32 {
    guard offset + 4 <= data.count else { throw EXIFError.truncatedData }
    let start = data.startIndex + offset
    let raw = UInt32(data[start]) << 24 | UInt32(data[start + 1]) << 16
      | UInt32(data[start + 2]) << 8 | UInt32(data[start + 3])
    offset += 4
    switch byteOrder {
      case .big: return raw
      case .little: return raw.byteSwapped
    }
  }

  mutating func readInt32() throws -> Int32 {
    Int32(bitPattern: try readUInt32())
  }

  mutating func readBytes(_ count: Int) throws -> Data {
    guard offset + count <= data.count else { throw EXIFError.truncatedData }
    let start = data.startIndex + offset
    let result = data[start ..< start + count]
    offset += count
    return Data(result)
  }

  mutating func readASCII(_ count: Int) throws -> String {
    let bytes = try readBytes(count)
    // Strip null terminators and trailing whitespace
    let trimmed = bytes.prefix(while: { $0 != 0 })
    return String(data: Data(trimmed), encoding: .utf8)
      ?? String(data: Data(trimmed), encoding: .ascii)
      ?? ""
  }

  mutating func skip(_ count: Int) throws {
    guard offset + count <= data.count else { throw EXIFError.truncatedData }
    offset += count
  }

  /// Create a reader at a specific offset within the same data, inheriting byte order.
  func readerAt(_ offset: Int) -> ByteReader {
    ByteReader(data: data, offset: offset, byteOrder: byteOrder)
  }
}
