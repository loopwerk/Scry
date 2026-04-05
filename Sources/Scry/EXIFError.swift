import Foundation

public enum EXIFError: Error, CustomStringConvertible {
  case unsupportedFormat
  case invalidJPEGStructure
  case invalidPNGStructure
  case invalidWebPStructure
  case invalidTIFFHeader
  case noEXIFData
  case truncatedData
  case fileNotFound

  public var description: String {
    switch self {
      case .unsupportedFormat: "Unsupported image format"
      case .invalidJPEGStructure: "Invalid JPEG structure"
      case .invalidPNGStructure: "Invalid PNG structure"
      case .invalidWebPStructure: "Invalid WebP structure"
      case .invalidTIFFHeader: "Invalid TIFF header in EXIF data"
      case .noEXIFData: "No EXIF data found"
      case .truncatedData: "Unexpected end of data"
      case .fileNotFound: "File not found"
    }
  }
}
