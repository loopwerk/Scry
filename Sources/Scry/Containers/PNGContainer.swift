import Foundation

/// "XML:com.adobe.xmp\0", the keyword of the iTXt chunk that holds XMP
private let xmpKeyword = Data("XML:com.adobe.xmp".utf8) + Data([0x00])

enum PNGContainer {
  /// Extract EXIF and XMP data and the image size from a PNG file handle, reading only chunk headers plus the IHDR and metadata chunks.
  static func extractMetadata(from fileHandle: FileHandle) throws -> MetadataSegments {
    let sig = fileHandle.readData(ofLength: 8)
    guard sig.count == 8, sig[0] == 0x89, sig[1] == 0x50, sig[2] == 0x4E, sig[3] == 0x47 else {
      throw EXIFError.invalidPNGStructure
    }

    var segments = MetadataSegments()

    while true {
      // Read chunk header: 4 bytes length + 4 bytes type
      let header = fileHandle.readData(ofLength: 8)
      guard header.count == 8 else { break }

      let length = Int(header[0]) << 24 | Int(header[1]) << 16
        | Int(header[2]) << 8 | Int(header[3])
      let chunkType = String(data: header[4 ..< 8], encoding: .ascii) ?? ""

      if chunkType == "IEND" { break }

      if chunkType == "IHDR" || chunkType == "eXIf" || chunkType == "iTXt" {
        let chunkData = fileHandle.readData(ofLength: length)
        guard chunkData.count == length else { throw EXIFError.truncatedData }

        if chunkType == "IHDR" {
          // Width and height (4 bytes each, big-endian)
          guard length >= 8 else { throw EXIFError.invalidPNGStructure }
          let width = Int(chunkData[0]) << 24 | Int(chunkData[1]) << 16 | Int(chunkData[2]) << 8 | Int(chunkData[3])
          let height = Int(chunkData[4]) << 24 | Int(chunkData[5]) << 16 | Int(chunkData[6]) << 8 | Int(chunkData[7])
          if width > 0, height > 0 {
            segments.dimensions = (width, height)
          }
        } else if chunkType == "eXIf" {
          segments.exif = segments.exif ?? chunkData
        } else if segments.xmp == nil, chunkData.starts(with: xmpKeyword) {
          segments.xmp = xmpText(fromITXt: chunkData)
        }

        // Skip 4 bytes CRC
        fileHandle.seek(toFileOffset: fileHandle.offsetInFile + 4)
      } else {
        // Skip chunk data + 4 bytes CRC
        fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(length + 4))
      }
    }

    return segments
  }

  /// The text of an iTXt chunk: keyword\0, compression flag, compression method,
  /// language tag\0, translated keyword\0, text. Compressed text is skipped, since
  /// inflating it would need zlib.
  private static func xmpText(fromITXt chunk: Data) -> Data? {
    var rest = chunk.dropFirst(xmpKeyword.count)
    guard rest.count >= 2, rest[rest.startIndex] == 0 else { return nil }
    rest = rest.dropFirst(2)

    // Language tag and translated keyword, both null-terminated
    for _ in 0 ..< 2 {
      guard let end = rest.firstIndex(of: 0) else { return nil }
      rest = rest[rest.index(after: end)...]
    }

    return Data(rest)
  }
}
