import Foundation

enum WebPContainer {
  /// Extract EXIF and XMP data from a WebP file handle, reading only chunk headers plus the metadata chunks.
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

      if fourCC == "EXIF" || fourCC == "XMP " {
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
}
