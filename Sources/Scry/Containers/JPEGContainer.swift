import Foundation

enum JPEGContainer {
  /// Extract EXIF TIFF data from a JPEG file.
  static func extractEXIF(from data: Data) throws -> Data {
    guard data.count >= 4,
          data[data.startIndex] == 0xFF,
          data[data.startIndex + 1] == 0xD8
    else {
      throw EXIFError.invalidJPEGStructure
    }

    var offset = 2

    while offset + 4 <= data.count {
      let start = data.startIndex + offset

      // Each marker starts with 0xFF
      guard data[start] == 0xFF else {
        throw EXIFError.invalidJPEGStructure
      }

      let marker = data[start + 1]

      // Skip padding bytes (0xFF 0xFF...)
      if marker == 0xFF {
        offset += 1
        continue
      }

      // SOS (Start of Scan) or EOI — no more metadata segments
      if marker == 0xDA || marker == 0xD9 {
        break
      }

      // Markers without a length field (RST, TEM, SOI)
      if marker == 0x00 || marker == 0x01 || (0xD0 ... 0xD7).contains(marker) {
        offset += 2
        continue
      }

      // Read segment length (includes the 2 length bytes but not the marker)
      guard offset + 4 <= data.count else { break }
      let length = Int(data[start + 2]) << 8 | Int(data[start + 3])
      guard length >= 2 else { throw EXIFError.invalidJPEGStructure }

      // APP1 marker (0xE1) — check for EXIF signature
      if marker == 0xE1 {
        let payloadStart = offset + 4
        let payloadLength = length - 2

        if payloadLength >= 6, payloadStart + 6 <= data.count {
          let sigStart = data.startIndex + payloadStart
          // "Exif\0\0"
          if data[sigStart] == 0x45, data[sigStart + 1] == 0x78,
             data[sigStart + 2] == 0x69, data[sigStart + 3] == 0x66,
             data[sigStart + 4] == 0x00, data[sigStart + 5] == 0x00
          {
            let tiffStart = payloadStart + 6
            let tiffLength = payloadLength - 6
            guard tiffStart + tiffLength <= data.count else { throw EXIFError.truncatedData }
            return Data(data[data.startIndex + tiffStart ..< data.startIndex + tiffStart + tiffLength])
          }
        }
      }

      // Move to next marker
      offset += 2 + length
    }

    throw EXIFError.noEXIFData
  }
}
