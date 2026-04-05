import Foundation

enum WebPContainer {
  /// Extract EXIF TIFF data from a WebP file handle, reading only chunk headers until EXIF is found.
  static func extractEXIF(from fileHandle: FileHandle) throws -> Data {
    let header = fileHandle.readData(ofLength: 12)
    guard header.count == 12,
          header[0] == 0x52, header[1] == 0x49, header[2] == 0x46, header[3] == 0x46,
          header[8] == 0x57, header[9] == 0x45, header[10] == 0x42, header[11] == 0x50
    else {
      throw EXIFError.invalidWebPStructure
    }

    while true {
      // Read chunk header: 4 bytes FourCC + 4 bytes size (little-endian)
      let chunkHeader = fileHandle.readData(ofLength: 8)
      guard chunkHeader.count == 8 else { break }

      let fourCC = String(data: chunkHeader[0 ..< 4], encoding: .ascii) ?? ""
      let size = Int(chunkHeader[4])
        | Int(chunkHeader[5]) << 8
        | Int(chunkHeader[6]) << 16
        | Int(chunkHeader[7]) << 24

      if fourCC == "EXIF" {
        var chunkData = fileHandle.readData(ofLength: size)
        guard chunkData.count == size else { throw EXIFError.truncatedData }

        // Some encoders prepend "Exif\0\0" like JPEG; strip if present
        if chunkData.count >= 6,
           chunkData[0] == 0x45, chunkData[1] == 0x78,
           chunkData[2] == 0x69, chunkData[3] == 0x66,
           chunkData[4] == 0x00, chunkData[5] == 0x00
        {
          chunkData = Data(chunkData.dropFirst(6))
        }

        return chunkData
      }

      // RIFF chunks are padded to even byte boundaries
      let paddedSize = size + (size % 2)
      fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(paddedSize))
    }

    throw EXIFError.noEXIFData
  }
}
