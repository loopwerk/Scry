import Foundation

enum PNGContainer {
  /// Extract EXIF TIFF data from a PNG file handle, reading only chunk headers until eXIf is found.
  static func extractEXIF(from fileHandle: FileHandle) throws -> Data {
    let sig = fileHandle.readData(ofLength: 8)
    guard sig.count == 8, sig[0] == 0x89, sig[1] == 0x50, sig[2] == 0x4E, sig[3] == 0x47 else {
      throw EXIFError.invalidPNGStructure
    }

    while true {
      // Read chunk header: 4 bytes length + 4 bytes type
      let header = fileHandle.readData(ofLength: 8)
      guard header.count == 8 else { break }

      let length = Int(header[0]) << 24 | Int(header[1]) << 16
        | Int(header[2]) << 8 | Int(header[3])
      let chunkType = String(data: header[4 ..< 8], encoding: .ascii) ?? ""

      if chunkType == "eXIf" {
        let chunkData = fileHandle.readData(ofLength: length)
        guard chunkData.count == length else { throw EXIFError.truncatedData }
        return chunkData
      }

      if chunkType == "IEND" { break }

      // Skip chunk data + 4 bytes CRC
      fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(length + 4))
    }

    throw EXIFError.noEXIFData
  }
}
