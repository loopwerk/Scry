import Foundation

enum PNGContainer {
  /// Extract EXIF TIFF data from a PNG file's eXIf chunk.
  static func extractEXIF(from data: Data) throws -> Data {
    // PNG signature: 89 50 4E 47 0D 0A 1A 0A
    guard data.count >= 8,
          data[data.startIndex] == 0x89,
          data[data.startIndex + 1] == 0x50,
          data[data.startIndex + 2] == 0x4E,
          data[data.startIndex + 3] == 0x47
    else {
      throw EXIFError.invalidPNGStructure
    }

    var offset = 8 // skip signature

    // Iterate through chunks: [4 bytes length][4 bytes type][data][4 bytes CRC]
    while offset + 8 <= data.count {
      let start = data.startIndex + offset

      // Chunk data length (big-endian)
      let length = Int(data[start]) << 24 | Int(data[start + 1]) << 16
        | Int(data[start + 2]) << 8 | Int(data[start + 3])

      // Chunk type (4 ASCII bytes)
      let typeStart = start + 4
      guard typeStart + 4 <= data.endIndex else { break }
      let chunkType = String(data: data[typeStart ..< typeStart + 4], encoding: .ascii) ?? ""

      let dataStart = offset + 8
      guard dataStart + length + 4 <= data.count else { break }

      if chunkType == "eXIf" {
        return Data(data[data.startIndex + dataStart ..< data.startIndex + dataStart + length])
      }

      // IEND — end of PNG
      if chunkType == "IEND" { break }

      // Move to next chunk: length field (4) + type (4) + data + CRC (4)
      offset += 12 + length
    }

    throw EXIFError.noEXIFData
  }
}
