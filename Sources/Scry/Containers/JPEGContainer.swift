import Foundation

enum JPEGContainer {
  /// Extract EXIF TIFF data from a JPEG file handle, reading only metadata segments.
  static func extractEXIF(from fileHandle: FileHandle) throws -> Data {
    let soi = fileHandle.readData(ofLength: 2)
    guard soi.count == 2, soi[0] == 0xFF, soi[1] == 0xD8 else {
      throw EXIFError.invalidJPEGStructure
    }

    while true {
      // Read marker (2 bytes)
      let markerData = fileHandle.readData(ofLength: 2)
      guard markerData.count == 2, markerData[0] == 0xFF else {
        throw EXIFError.invalidJPEGStructure
      }

      let marker = markerData[1]

      // Skip padding bytes
      if marker == 0xFF {
        fileHandle.seek(toFileOffset: fileHandle.offsetInFile - 1)
        continue
      }

      // SOS or EOI — no more metadata segments
      if marker == 0xDA || marker == 0xD9 { break }

      // Markers without a length field
      if marker == 0x00 || marker == 0x01 || (0xD0 ... 0xD7).contains(marker) {
        continue
      }

      // Read segment length
      let lengthData = fileHandle.readData(ofLength: 2)
      guard lengthData.count == 2 else { break }
      let length = Int(lengthData[0]) << 8 | Int(lengthData[1])
      guard length >= 2 else { throw EXIFError.invalidJPEGStructure }

      let payloadLength = length - 2

      // APP1 marker — check for EXIF signature
      if marker == 0xE1, payloadLength >= 6 {
        let sig = fileHandle.readData(ofLength: 6)
        guard sig.count == 6 else { throw EXIFError.truncatedData }
        // "Exif\0\0"
        if sig[0] == 0x45, sig[1] == 0x78, sig[2] == 0x69, sig[3] == 0x66,
           sig[4] == 0x00, sig[5] == 0x00
        {
          let tiffLength = payloadLength - 6
          let tiffData = fileHandle.readData(ofLength: tiffLength)
          guard tiffData.count == tiffLength else { throw EXIFError.truncatedData }
          return tiffData
        }
        // Not EXIF APP1, skip the rest of this segment
        let remaining = payloadLength - 6
        if remaining > 0 {
          fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(remaining))
        }
      } else {
        // Skip segment payload
        fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(payloadLength))
      }
    }

    throw EXIFError.noEXIFData
  }
}
