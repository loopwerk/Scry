import Foundation

/// "Exif\0\0"
private let exifSignature = Data([0x45, 0x78, 0x69, 0x66, 0x00, 0x00])
/// "http://ns.adobe.com/xap/1.0/\0"
private let xmpSignature = Data("http://ns.adobe.com/xap/1.0/".utf8) + Data([0x00])
/// Start-of-frame markers, which hold the image size. C4, C8 and CC are other markers in the same range.
private let sofMarkers: Set<UInt8> = [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF]

enum JPEGContainer {
  /// Extract EXIF and XMP data and the image size from a JPEG file handle, reading only the segments before the image data.
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
      } else if sofMarkers.contains(marker) {
        // Precision (1 byte), then height and width (2 bytes each, big-endian)
        let payload = fileHandle.readData(ofLength: payloadLength)
        guard payload.count == payloadLength, payloadLength >= 5 else { throw EXIFError.truncatedData }

        let height = Int(payload[1]) << 8 | Int(payload[2])
        let width = Int(payload[3]) << 8 | Int(payload[4])
        if segments.dimensions == nil, width > 0, height > 0 {
          segments.dimensions = (width, height)
        }
      } else {
        // Skip segment payload
        fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(payloadLength))
      }
    }

    return segments
  }
}
