import Foundation

/// "Exif\0\0"
private let exifSignature = Data([0x45, 0x78, 0x69, 0x66, 0x00, 0x00])
/// "http://ns.adobe.com/xap/1.0/\0"
private let xmpSignature = Data("http://ns.adobe.com/xap/1.0/".utf8) + Data([0x00])

enum JPEGContainer {
  /// Extract EXIF and XMP data from a JPEG file handle, reading only metadata segments.
  static func extractMetadata(from fileHandle: FileHandle) throws -> MetadataSegments {
    let soi = fileHandle.readData(ofLength: 2)
    guard soi.count == 2, soi[0] == 0xFF, soi[1] == 0xD8 else {
      throw EXIFError.invalidJPEGStructure
    }

    var segments = MetadataSegments()

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

      // APP1 marker — holds either EXIF or XMP, told apart by their signature
      if marker == 0xE1 {
        let payload = fileHandle.readData(ofLength: payloadLength)
        guard payload.count == payloadLength else { throw EXIFError.truncatedData }

        if segments.exif == nil, payload.starts(with: exifSignature) {
          segments.exif = Data(payload.dropFirst(exifSignature.count))
        } else if segments.xmp == nil, payload.starts(with: xmpSignature) {
          segments.xmp = Data(payload.dropFirst(xmpSignature.count))
        }
      } else {
        // Skip segment payload
        fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(payloadLength))
      }
    }

    return segments
  }
}
