import Foundation

// TIFF data type IDs
private let typeByte: UInt16 = 1
private let typeASCII: UInt16 = 2
private let typeShort: UInt16 = 3
private let typeLong: UInt16 = 4
private let typeRational: UInt16 = 5
private let typeUndefined: UInt16 = 7
private let typeSLong: UInt16 = 9
private let typeSRational: UInt16 = 10

/// Size in bytes per element for each TIFF type.
private func typeSize(_ type: UInt16) -> Int {
  switch type {
    case typeByte, typeASCII, typeUndefined: 1
    case typeShort: 2
    case typeLong, typeSLong: 4
    case typeRational, typeSRational: 8
    default: 0
  }
}

enum TIFFParser {
  /// Parse TIFF/IFD structured EXIF data and return a flat dictionary.
  /// Keys are human-readable tag names (e.g. "Make", "FocalLength").
  static func parse(_ data: Data) throws -> [String: Any]? {
    guard data.count >= 8 else { return nil }

    var reader = ByteReader(data: data)

    // Read byte order mark (read raw before setting byte order)
    let b0 = try reader.readUInt8()
    let b1 = try reader.readUInt8()
    if b0 == 0x49 && b1 == 0x49 {
      reader.byteOrder = .little
    } else if b0 == 0x4D && b1 == 0x4D {
      reader.byteOrder = .big
    } else {
      throw EXIFError.invalidTIFFHeader
    }

    // Verify magic number 42
    let magic = try reader.readUInt16()
    guard magic == 42 else { throw EXIFError.invalidTIFFHeader }

    // Offset to IFD0
    let ifd0Offset = try reader.readUInt32()
    guard ifd0Offset < data.count else { return nil }

    var result: [String: Any] = [:]
    var exifOffset: UInt32?
    var gpsOffset: UInt32?

    // Parse IFD0 (TIFF tags)
    let ifd0 = try parseIFD(data: data, offset: Int(ifd0Offset), byteOrder: reader.byteOrder)
    for entry in ifd0 {
      if entry.tag == exifIFDPointer {
        exifOffset = valueAsUInt32(entry, data: data, byteOrder: reader.byteOrder)
      } else if entry.tag == gpsIFDPointer {
        gpsOffset = valueAsUInt32(entry, data: data, byteOrder: reader.byteOrder)
      } else if let (name, value) = resolveTag(entry, group: .tiff, data: data, byteOrder: reader.byteOrder) {
        result[name] = value
      }
    }

    // Parse EXIF sub-IFD
    if let offset = exifOffset, offset < data.count {
      let entries = try parseIFD(data: data, offset: Int(offset), byteOrder: reader.byteOrder)
      for entry in entries {
        if let (name, value) = resolveTag(entry, group: .exif, data: data, byteOrder: reader.byteOrder) {
          result[name] = value
        }
      }
    }

    // Parse GPS sub-IFD
    if let offset = gpsOffset, offset < data.count {
      let entries = try parseIFD(data: data, offset: Int(offset), byteOrder: reader.byteOrder)
      for entry in entries {
        if let (name, value) = resolveTag(entry, group: .gps, data: data, byteOrder: reader.byteOrder) {
          result[name] = value
        }
      }
    }

    return result.isEmpty ? nil : result
  }
}

// MARK: - IFD Entry

private struct IFDEntry {
  let tag: UInt16
  let type: UInt16
  let count: UInt32
  /// The raw 4 bytes of the value/offset field.
  let valueOffset: Data
}

// MARK: - IFD Parsing

private func parseIFD(data: Data, offset: Int, byteOrder: ByteReader.ByteOrder) throws -> [IFDEntry] {
  var reader = ByteReader(data: data, offset: offset, byteOrder: byteOrder)
  guard reader.remaining >= 2 else { return [] }

  let count = try reader.readUInt16()
  guard reader.remaining >= Int(count) * 12 else { return [] }

  var entries: [IFDEntry] = []
  entries.reserveCapacity(Int(count))

  for _ in 0 ..< count {
    let tag = try reader.readUInt16()
    let type = try reader.readUInt16()
    let cnt = try reader.readUInt32()
    let valBytes = try reader.readBytes(4)
    entries.append(IFDEntry(tag: tag, type: type, count: cnt, valueOffset: valBytes))
  }

  return entries
}

// MARK: - Value extraction

/// Get the data bytes for an IFD entry's value.
/// If the value fits in 4 bytes it's inline; otherwise valueOffset is a pointer.
private func valueData(for entry: IFDEntry, data: Data, byteOrder: ByteReader.ByteOrder) -> Data? {
  let totalSize = Int(entry.count) * typeSize(entry.type)
  if totalSize <= 4 {
    return Data(entry.valueOffset.prefix(totalSize))
  }

  // Read offset from the 4-byte field
  var r = ByteReader(data: Data(entry.valueOffset), byteOrder: byteOrder)
  guard let offset = try? r.readUInt32() else { return nil }
  let start = Int(offset)
  guard start >= 0, start + totalSize <= data.count else { return nil }
  return Data(data[data.startIndex + start ..< data.startIndex + start + totalSize])
}

/// Extract a UInt32 from an IFD entry (used for sub-IFD pointers).
private func valueAsUInt32(_ entry: IFDEntry, data: Data, byteOrder: ByteReader.ByteOrder) -> UInt32? {
  var r = ByteReader(data: Data(entry.valueOffset), byteOrder: byteOrder)
  return try? r.readUInt32()
}

/// Resolve an IFD entry to a (name, value) pair.
private func resolveTag(_ entry: IFDEntry, group: TagGroup, data: Data, byteOrder: ByteReader.ByteOrder) -> (String, Any)? {
  guard let name = tagName(for: entry.tag, group: group) else { return nil }
  guard let valData = valueData(for: entry, data: data, byteOrder: byteOrder) else { return nil }

  let value: Any?

  switch entry.type {
    case typeByte:
      if entry.count == 1 {
        value = Int(valData[valData.startIndex])
      } else {
        value = Array(valData).map { Int($0) }
      }

    case typeASCII:
      let trimmed = valData.prefix(while: { $0 != 0 })
      value = String(data: Data(trimmed), encoding: .utf8)
        ?? String(data: Data(trimmed), encoding: .ascii)

    case typeShort:
      var r = ByteReader(data: valData, byteOrder: byteOrder)
      if entry.count == 1 {
        value = try? Int(r.readUInt16())
      } else {
        var arr: [Int] = []
        for _ in 0 ..< entry.count {
          guard let v = try? r.readUInt16() else { break }
          arr.append(Int(v))
        }
        value = arr
      }

    case typeLong:
      var r = ByteReader(data: valData, byteOrder: byteOrder)
      if entry.count == 1 {
        value = try? Int(r.readUInt32())
      } else {
        var arr: [Int] = []
        for _ in 0 ..< entry.count {
          guard let v = try? r.readUInt32() else { break }
          arr.append(Int(v))
        }
        value = arr
      }

    case typeRational:
      var r = ByteReader(data: valData, byteOrder: byteOrder)
      if entry.count == 1 {
        guard let num = try? r.readUInt32(), let den = try? r.readUInt32() else { return nil }
        value = den == 0 ? 0.0 : Double(num) / Double(den)
      } else {
        var arr: [Double] = []
        for _ in 0 ..< entry.count {
          guard let num = try? r.readUInt32(), let den = try? r.readUInt32() else { break }
          arr.append(den == 0 ? 0.0 : Double(num) / Double(den))
        }
        value = arr
      }

    case typeSLong:
      var r = ByteReader(data: valData, byteOrder: byteOrder)
      if entry.count == 1 {
        value = try? Int(r.readInt32())
      } else {
        var arr: [Int] = []
        for _ in 0 ..< entry.count {
          guard let v = try? r.readInt32() else { break }
          arr.append(Int(v))
        }
        value = arr
      }

    case typeSRational:
      var r = ByteReader(data: valData, byteOrder: byteOrder)
      if entry.count == 1 {
        guard let num = try? r.readInt32(), let den = try? r.readInt32() else { return nil }
        value = den == 0 ? 0.0 : Double(num) / Double(den)
      } else {
        var arr: [Double] = []
        for _ in 0 ..< entry.count {
          guard let num = try? r.readInt32(), let den = try? r.readInt32() else { break }
          arr.append(den == 0 ? 0.0 : Double(num) / Double(den))
        }
        value = arr
      }

    case typeUndefined:
      // Return as raw bytes array for version tags etc.
      value = Array(valData)

    default:
      value = nil
  }

  guard let value else { return nil }
  return (name, value)
}
