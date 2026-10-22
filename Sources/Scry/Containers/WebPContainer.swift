import Foundation

/// Image chunks that start with the image size: the extended header and the lossy and lossless bitstreams
private let sizeChunks: Set<String> = ["VP8X", "VP8 ", "VP8L"]
/// Enough of a size chunk to read the size from, for all three kinds
private let sizeHeaderLength = 10

enum WebPContainer {
  /// Extract EXIF and XMP data and the image size from a WebP file handle, reading only chunk headers plus the
  /// start of the image chunks and the metadata chunks.
  static func extractMetadata(from fileHandle: FileHandle) throws -> MetadataSegments {
    let header = fileHandle.readData(ofLength: 12)
    guard header.count == 12,
          header[0] == 0x52, header[1] == 0x49, header[2] == 0x46, header[3] == 0x46,
          header[8] == 0x57, header[9] == 0x45, header[10] == 0x42, header[11] == 0x50
    else {
      throw EXIFError.invalidWebPStructure
    }

    var segments = MetadataSegments()

    while true {
      // Read chunk header: 4 bytes FourCC + 4 bytes size (little-endian)
      let chunkHeader = fileHandle.readData(ofLength: 8)
      guard chunkHeader.count == 8 else { break }

      let fourCC = String(data: chunkHeader[0 ..< 4], encoding: .ascii) ?? ""
      let size = Int(chunkHeader[4])
        | Int(chunkHeader[5]) << 8
        | Int(chunkHeader[6]) << 16
        | Int(chunkHeader[7]) << 24

      // RIFF chunks are padded to even byte boundaries
      let padding = size % 2

      if sizeChunks.contains(fourCC) {
        // An extended file has a VP8X chunk before its bitstream chunk; the first one found wins
        let readLength = min(size, sizeHeaderLength)
        let chunkStart = fileHandle.readData(ofLength: readLength)
        guard chunkStart.count == readLength else { throw EXIFError.truncatedData }

        if segments.dimensions == nil {
          segments.dimensions = dimensions(fourCC: fourCC, chunkStart: chunkStart)
        }

        fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(size - readLength + padding))
      } else if fourCC == "EXIF" || fourCC == "XMP " {
        var chunkData = fileHandle.readData(ofLength: size)
        guard chunkData.count == size else { throw EXIFError.truncatedData }

        if fourCC == "EXIF" {
          // Some encoders prepend "Exif\0\0" like JPEG; strip if present
          if chunkData.count >= 6,
             chunkData[0] == 0x45, chunkData[1] == 0x78,
             chunkData[2] == 0x69, chunkData[3] == 0x66,
             chunkData[4] == 0x00, chunkData[5] == 0x00
          {
            chunkData = Data(chunkData.dropFirst(6))
          }
          segments.exif = segments.exif ?? chunkData
        } else {
          segments.xmp = segments.xmp ?? chunkData
        }

        fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(padding))
      } else {
        fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(size + padding))
      }
    }

    return segments
  }

  /// The image size from the start of a VP8X, VP8 or VP8L chunk, or nil when the chunk is malformed.
  private static func dimensions(fourCC: String, chunkStart data: Data) -> (width: Int, height: Int)? {
    switch fourCC {
      case "VP8X":
        // Flags and reserved (4 bytes), then canvas width - 1 and height - 1 (3 bytes each, little-endian)
        guard data.count >= 10 else { return nil }
        let width = (Int(data[4]) | Int(data[5]) << 8 | Int(data[6]) << 16) + 1
        let height = (Int(data[7]) | Int(data[8]) << 8 | Int(data[9]) << 16) + 1
        return (width, height)

      case "VP8 ":
        // Frame tag (3 bytes) and start code 9D 01 2A, then width and height (14 bits each in 2 little-endian bytes)
        guard data.count >= 10, data[3] == 0x9D, data[4] == 0x01, data[5] == 0x2A else { return nil }
        let width = (Int(data[6]) | Int(data[7]) << 8) & 0x3FFF
        let height = (Int(data[8]) | Int(data[9]) << 8) & 0x3FFF
        return width > 0 && height > 0 ? (width, height) : nil

      case "VP8L":
        // Signature byte 0x2F, then width - 1 and height - 1 packed as 14 bits each into 4 little-endian bytes
        guard data.count >= 5, data[0] == 0x2F else { return nil }
        let bits = Int(data[1]) | Int(data[2]) << 8 | Int(data[3]) << 16 | Int(data[4]) << 24
        return ((bits & 0x3FFF) + 1, (bits >> 14 & 0x3FFF) + 1)

      default:
        return nil
    }
  }
}
