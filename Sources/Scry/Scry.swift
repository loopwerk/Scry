import Foundation

enum ImageFormat {
  case jpeg, png, webp
}

public enum Scry {
  /// Extract metadata from a file at the given path.
  /// Returns nil if the format is unsupported or no EXIF data is found.
  /// Only reads the metadata segments, not the entire image.
  public static func metadata(fromFileAt path: String) throws -> [String: Any]? {
    guard let fileHandle = FileHandle(forReadingAtPath: path) else {
      throw EXIFError.fileNotFound
    }
    defer { fileHandle.closeFile() }

    // Read first 12 bytes for format detection
    let header = fileHandle.readData(ofLength: 12)
    let format = try detectFormat(header)

    fileHandle.seek(toFileOffset: 0)

    let exifBytes: Data
    do {
      switch format {
        case .jpeg: exifBytes = try JPEGContainer.extractEXIF(from: fileHandle)
        case .png: exifBytes = try PNGContainer.extractEXIF(from: fileHandle)
        case .webp: exifBytes = try WebPContainer.extractEXIF(from: fileHandle)
      }
    } catch is EXIFError {
      return nil
    }

    return try TIFFParser.parse(exifBytes)
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
