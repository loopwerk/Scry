import Foundation
@testable import Scry
import Testing

/// Shared assertions for metadata extracted from the test image (an iPhone 14 Pro photo).
private func assertCommonMetadata(_ meta: [String: Any]) {
  // TIFF tags
  #expect(meta["Make"] as? String == "Apple")
  #expect(meta["Model"] as? String == "iPhone 14 Pro")
  #expect(meta["Orientation"] as? Int == 1)
  #expect(meta["Software"] as? String == "18.7.3")
  #expect(meta["DateTime"] as? String == "2026:01:05 17:11:42")
  #expect(meta["HostComputer"] as? String == "iPhone 14 Pro")
  #expect(meta["XResolution"] as? Double == 72.0)
  #expect(meta["YResolution"] as? Double == 72.0)
  #expect(meta["ResolutionUnit"] as? Int == 2)

  // EXIF tags
  #expect(meta["FNumber"] as? Double == 1.78)
  #expect(meta["ExposureTime"] as? Double == 0.04)
  #expect(meta["ISOSpeedRatings"] as? Int == 800)
  #expect(meta["FocalLength"] as? Double == 6.86)
  #expect(meta["FocalLenIn35mmFilm"] as? Int == 24)
  #expect(meta["LensModel"] as? String == "iPhone 14 Pro back triple camera 6.86mm f/1.78")
  #expect(meta["LensMake"] as? String == "Apple")
  #expect(meta["ApertureValue"] as? Double == 1.663754482562451)
  #expect(meta["BrightnessValue"] as? Double == -2.504312203536007)
  #expect(meta["ExposureBiasValue"] as? Double == 0.0)
  #expect(meta["ShutterSpeedValue"] as? Double == 4.6438201187894785)
  #expect(meta["MeteringMode"] as? Int == 5)
  #expect(meta["Flash"] as? Int == 16)
  #expect(meta["WhiteBalance"] as? Int == 0)
  #expect(meta["ExposureMode"] as? Int == 0)
  #expect(meta["ExposureProgram"] as? Int == 2)
  #expect(meta["SceneCaptureType"] as? Int == 0)
  #expect(meta["DateTimeOriginal"] as? String == "2026:01:05 17:11:42")
  #expect(meta["DateTimeDigitized"] as? String == "2026:01:05 17:11:42")
  #expect(meta["OffsetTime"] as? String == "+01:00")
  #expect(meta["OffsetTimeOriginal"] as? String == "+01:00")
  #expect(meta["PixelXDimension"] as? Int == 150)
  #expect(meta["PixelYDimension"] as? Int == 200)

  // GPS tags
  #expect(meta["GPSLatitude"] as? [Double] == [52.0, 31.0, 12.74])
  #expect(meta["GPSLongitude"] as? [Double] == [13.0, 24.0, 36.33])
  #expect(meta["GPSLatitudeRef"] as? String == "N")
  #expect(meta["GPSLongitudeRef"] as? String == "E")
  #expect(meta["GPSAltitude"] as? Double == 38.39345262301749)
  #expect(meta["GPSAltitudeRef"] as? Int == 0)
  #expect(meta["GPSSpeed"] as? Double == 0.0)
  #expect(meta["GPSImgDirection"] as? Double == 139.5602417067456)
  #expect(meta["GPSDateStamp"] as? String == "2026:01:05")
  #expect(meta["GPSDestBearing"] as? Double == 139.5602417067456)
}

private func fixtureURL(_ name: String, ext: String) -> URL {
  Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")!
}

// MARK: - Format-specific tests

@Test func jPEG() throws {
  let meta = try Scry.metadata(fromFileAt: fixtureURL("test", ext: "jpg").path)
  #expect(meta != nil)
  assertCommonMetadata(try #require(meta))
}

@Test func pNG() throws {
  let meta = try Scry.metadata(fromFileAt: fixtureURL("test", ext: "png").path)
  #expect(meta != nil)
  assertCommonMetadata(try #require(meta))
}

@Test func webP() throws {
  let meta = try Scry.metadata(fromFileAt: fixtureURL("test", ext: "webp").path)
  #expect(meta != nil)
  assertCommonMetadata(try #require(meta))
}

// MARK: - XMP

/// Shared assertions for the XMP packet in the test-xmp fixtures (the test images with their EXIF replaced by XMP).
private func assertXMPMetadata(_ meta: [String: Any]) {
  // Attributes on rdf:Description
  #expect(meta["Make"] as? String == "FUJIFILM")
  #expect(meta["Model"] as? String == "X-E3")
  #expect(meta["FocalLenIn35mmFilm"] as? Int == 53)

  // Elements, with rationals converted like the EXIF parser does
  #expect(meta["FNumber"] as? Double == 8.0)
  #expect(meta["ExposureTime"] as? Double == 0.01)
  #expect(meta["FocalLength"] as? Double == 35.0)
  #expect(meta["LensModel"] as? String == "XF35mmF1.4 R")

  // First item of rdf:Seq / rdf:Alt, with entities decoded
  #expect(meta["ISOSpeedRatings"] as? Int == 200)
  #expect(meta["Artist"] as? String == "Kevin Renskers")
  #expect(meta["Copyright"] as? String == "2026 Kevin & Co")

  // The Flash struct folded back into the EXIF bit field
  #expect(meta["Flash"] as? Int == 16)

  // ISO 8601 dates in EXIF format
  #expect(meta["DateTimeOriginal"] as? String == "2026:04:11 13:21:58")
  #expect(meta["DateTimeDigitized"] as? String == "2026:04:11 13:21:58")

  // GPS coordinates split into degrees, minutes, seconds and a reference
  #expect(meta["GPSLatitude"] as? [Double] == [52.0, 31.0, 12.744])
  #expect(meta["GPSLatitudeRef"] as? String == "N")
  #expect(meta["GPSLongitude"] as? [Double] == [13.0, 24.0, 36.33])
  #expect(meta["GPSLongitudeRef"] as? String == "E")
  #expect(meta["GPSAltitude"] as? Double == 38.39)
  #expect(meta["GPSAltitudeRef"] as? Int == 0)
}

@Test func xmpOnlyJPEG() throws {
  let meta = try Scry.metadata(fromFileAt: fixtureURL("test-xmp", ext: "jpg").path)
  assertXMPMetadata(try #require(meta))
}

@Test func xmpOnlyPNG() throws {
  let meta = try Scry.metadata(fromFileAt: fixtureURL("test-xmp", ext: "png").path)
  assertXMPMetadata(try #require(meta))
}

@Test func xmpOnlyWebP() throws {
  let meta = try Scry.metadata(fromFileAt: fixtureURL("test-xmp", ext: "webp").path)
  assertXMPMetadata(try #require(meta))
}

@Test func exifWinsOverXMP() throws {
  // The XMP in this fixture says Make is "Not Apple", and adds fields the EXIF doesn't have
  let meta = try #require(try Scry.metadata(fromFileAt: fixtureURL("test-exif-xmp", ext: "webp").path))
  assertCommonMetadata(meta)
  #expect(meta["Artist"] as? String == "Kevin Renskers")
}

@Test func xmpNamespacesAreMatchedByURI() {
  let xmp = """
  <x:xmpmeta xmlns:x="adobe:ns:meta/">
   <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description xmlns:t="http://ns.adobe.com/tiff/1.0/" xmlns:other="http://example.com/"
      t:Make='Canon' other:Model="Not a camera">
     <photoshop:DateCreated>2026-04-11</photoshop:DateCreated>
    </rdf:Description>
   </rdf:RDF>
  </x:xmpmeta>
  """
  let meta = XMPParser.parse(Data(xmp.utf8))
  #expect(meta["Make"] as? String == "Canon")
  // Unknown namespace, and a prefix that was never declared
  #expect(meta["Model"] == nil)
  #expect(meta["DateTimeOriginal"] == nil)
}

@Test func xmpDates() {
  let xmp = """
  <rdf:Description xmlns:exif="http://ns.adobe.com/exif/1.0/" xmlns:xmp="http://ns.adobe.com/xap/1.0/"
    exif:DateTimeOriginal="2026-04-11" xmp:ModifyDate="2026-04-12T08:05Z"/>
  """
  let meta = XMPParser.parse(Data(xmp.utf8))
  #expect(meta["DateTimeOriginal"] as? String == "2026:04:11 00:00:00")
  #expect(meta["DateTime"] as? String == "2026:04:12 08:05:00")
}

// MARK: - General tests

@Test func formatDetection() throws {
  let jpeg = try Data(contentsOf: fixtureURL("test", ext: "jpg"))
  #expect(try Scry.detectFormat(jpeg) == .jpeg)

  let png = try Data(contentsOf: fixtureURL("test", ext: "png"))
  #expect(try Scry.detectFormat(png) == .png)

  let webp = try Data(contentsOf: fixtureURL("test", ext: "webp"))
  #expect(try Scry.detectFormat(webp) == .webp)

  let gif = try Data(contentsOf: fixtureURL("test", ext: "gif"))
  #expect(throws: EXIFError.unsupportedFormat) {
    try Scry.detectFormat(gif)
  }
}

@Test func unsupportedFormat() throws {
  #expect(throws: EXIFError.unsupportedFormat) {
    try Scry.metadata(fromFileAt: fixtureURL("test", ext: "gif").path)
  }
}

@Test func fileNotFound() throws {
  #expect(throws: EXIFError.fileNotFound) {
    try Scry.metadata(fromFileAt: "/nonexistent/path.jpg")
  }
}
