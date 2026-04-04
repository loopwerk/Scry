import Foundation

enum TIFFContainer {
  /// For TIFF files, the entire file is the TIFF structure — pass through.
  static func extractEXIF(from data: Data) throws -> Data {
    guard data.count >= 8,
          (data[data.startIndex] == 0x49 && data[data.startIndex + 1] == 0x49)
          || (data[data.startIndex] == 0x4D && data[data.startIndex + 1] == 0x4D)
    else {
      throw EXIFError.invalidTIFFHeader
    }
    return data
  }
}
