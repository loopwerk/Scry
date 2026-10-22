import Foundation

/// The raw metadata payloads found in an image container, plus the image size from its header.
struct MetadataSegments {
  /// TIFF-structured EXIF data, without any "Exif\0\0" prefix.
  var exif: Data?
  /// An XMP packet (UTF-8 XML).
  var xmp: Data?
  /// The pixel size as stored in the image header, before any EXIF orientation is applied.
  var dimensions: (width: Int, height: Int)?
}
