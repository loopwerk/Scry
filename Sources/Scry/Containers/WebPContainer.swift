import Foundation

enum WebPContainer {
  /// Extract EXIF TIFF data from a WebP file's EXIF chunk.
  static func extractEXIF(from data: Data) throws -> Data {
    // RIFF header: "RIFF" + 4 bytes size + "WEBP"
    guard data.count >= 12,
          data[data.startIndex] == 0x52, // R
          data[data.startIndex + 1] == 0x49, // I
          data[data.startIndex + 2] == 0x46, // F
          data[data.startIndex + 3] == 0x46, // F
          data[data.startIndex + 8] == 0x57, // W
          data[data.startIndex + 9] == 0x45, // E
          data[data.startIndex + 10] == 0x42, // B
          data[data.startIndex + 11] == 0x50 // P
    else {
      throw EXIFError.invalidWebPStructure
    }

    var offset = 12 // after "RIFF" + size + "WEBP"

    // Scan RIFF chunks: [4 bytes FourCC][4 bytes size (little-endian)][data][padding to even]
    while offset + 8 <= data.count {
      let start = data.startIndex + offset
      let fourCC = String(data: data[start ..< start + 4], encoding: .ascii) ?? ""

      // Size is little-endian
      let size = Int(data[start + 4])
        | Int(data[start + 5]) << 8
        | Int(data[start + 6]) << 16
        | Int(data[start + 7]) << 24

      let dataStart = offset + 8
      guard dataStart + size <= data.count else { break }

      if fourCC == "EXIF" {
        var exifStart = dataStart
        var exifSize = size

        // Some encoders prepend "Exif\0\0" like JPEG; strip if present
        if exifSize >= 6 {
          let s = data.startIndex + exifStart
          if data[s] == 0x45, data[s + 1] == 0x78,
             data[s + 2] == 0x69, data[s + 3] == 0x66,
             data[s + 4] == 0x00, data[s + 5] == 0x00
          {
            exifStart += 6
            exifSize -= 6
          }
        }

        return Data(data[data.startIndex + exifStart ..< data.startIndex + exifStart + exifSize])
      }

      // RIFF chunks are padded to even byte boundaries
      offset = dataStart + size + (size % 2)
    }

    throw EXIFError.noEXIFData
  }
}
