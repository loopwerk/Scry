import Foundation

/// The raw metadata payloads found in an image container.
struct MetadataSegments {
  /// TIFF-structured EXIF data, without any "Exif\0\0" prefix.
  var exif: Data?
  /// An XMP packet (UTF-8 XML).
  var xmp: Data?
}
