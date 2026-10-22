import Foundation

enum ImageFormat {
  case jpeg, png, webp
}

public enum Scry {
  /// Extract metadata from a file at the given path.
  /// Reads both EXIF and XMP; when a field is in both, the EXIF value wins.
  /// Returns nil if the format is unsupported or no metadata is found.
  /// Only reads the metadata segments, not the entire image.
  public static func metadata(fromFileAt path: String) throws -> [String: Any]? {
    let segments: MetadataSegments
    do {
      segments = try readContainer(atPath: path)
    } catch let error as EXIFError where error != .fileNotFound && error != .unsupportedFormat {
      return nil
    }

    var result: [String: Any] = [:]

    if let xmp = segments.xmp {
      result = XMPParser.parse(xmp)
    }

    if let exif = segments.exif, let exifValues = try TIFFParser.parse(exif) {
      result.merge(exifValues) { _, exifValue in exifValue }
    }

    return result.isEmpty ? nil : result
  }

  /// Read the pixel size of the image at the given path from its header, without decoding the image.
  /// This is the size as stored; it does not account for the EXIF `Orientation`.
  public static func dimensions(fromFileAt path: String) throws -> (width: Int, height: Int) {
    guard let dimensions = try readContainer(atPath: path).dimensions else {
      throw EXIFError.noDimensions
    }
    return dimensions
  }

  private static func readContainer(atPath path: String) throws -> MetadataSegments {
    guard let fileHandle = FileHandle(forReadingAtPath: path) else {
      throw EXIFError.fileNotFound
    }
    defer { fileHandle.closeFile() }

    // Read first 12 bytes for format detection
    let header = fileHandle.readData(ofLength: 12)
    let format = try detectFormat(header)

    fileHandle.seek(toFileOffset: 0)

    switch format {
      case .jpeg: return try JPEGContainer.extractMetadata(from: fileHandle)
      case .png: return try PNGContainer.extractMetadata(from: fileHandle)
      case .webp: return try WebPContainer.extractMetadata(from: fileHandle)
    }
  }

  /// Detect image format from magic bytes.
  /// Throws `unsupportedFormat` if the bytes don't match any supported format.
  static func detectFormat(_ data: Data) throws -> ImageFormat {
    guard data.count >= 12 else { throw EXIFError.unsupportedFormat }
    let s = data.startIndex

    // JPEG: FF D8 FF
    if data[s] == 0xFF, data[s + 1] == 0xD8, data[s + 2] == 0xFF {
      return .jpeg
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if data[s] == 0x89, data[s + 1] == 0x50, data[s + 2] == 0x4E, data[s + 3] == 0x47 {
      return .png
    }

    // WebP: RIFF....WEBP
    if data[s] == 0x52, data[s + 1] == 0x49, data[s + 2] == 0x46, data[s + 3] == 0x46,
       data[s + 8] == 0x57, data[s + 9] == 0x45, data[s + 10] == 0x42, data[s + 11] == 0x50
    {
      return .webp
    }

    throw EXIFError.unsupportedFormat
  }
}
