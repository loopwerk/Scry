import Foundation

public enum ImageFormat {
  case jpeg, png, webp, tiff
}

public enum Scry {
  /// Extract metadata from a file at the given path.
  /// Returns nil if the format is unsupported or no EXIF data is found.
  public static func metadata(fromFileAt path: String) throws -> [String: Any]? {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try metadata(from: data)
  }

  /// Extract metadata from raw image data.
  /// Detects the image format from magic bytes.
  public static func metadata(from data: Data) throws -> [String: Any]? {
    guard let format = detectFormat(data) else { return nil }
    return try metadata(from: data, format: format)
  }

  /// Extract metadata from raw image data with an explicit format.
  public static func metadata(from data: Data, format: ImageFormat) throws -> [String: Any]? {
    let exifBytes: Data
    do {
      switch format {
        case .jpeg: exifBytes = try JPEGContainer.extractEXIF(from: data)
        case .png: exifBytes = try PNGContainer.extractEXIF(from: data)
        case .webp: exifBytes = try WebPContainer.extractEXIF(from: data)
        case .tiff: exifBytes = try TIFFContainer.extractEXIF(from: data)
      }
    } catch is EXIFError {
      return nil
    }
    return try TIFFParser.parse(exifBytes)
  }

  /// Detect image format from magic bytes.
  public static func detectFormat(_ data: Data) -> ImageFormat? {
    guard data.count >= 12 else { return nil }
    let s = data.startIndex
    // JPEG: FF D8 FF
    if data[s] == 0xFF && data[s + 1] == 0xD8 && data[s + 2] == 0xFF { return .jpeg }
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if data[s] == 0x89 && data[s + 1] == 0x50 && data[s + 2] == 0x4E && data[s + 3] == 0x47 { return .png }
    // WebP: RIFF....WEBP
    if data[s] == 0x52 && data[s + 1] == 0x49 && data[s + 2] == 0x46 && data[s + 3] == 0x46
      && data[s + 8] == 0x57 && data[s + 9] == 0x45 && data[s + 10] == 0x42 && data[s + 11] == 0x50 { return .webp }
    // TIFF: "II" (little-endian) or "MM" (big-endian)
    if (data[s] == 0x49 && data[s + 1] == 0x49) || (data[s] == 0x4D && data[s + 1] == 0x4D) { return .tiff }
    return nil
  }
}
