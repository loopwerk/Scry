import Foundation

/// Reads the EXIF-equivalent fields from an XMP packet, using the same keys and value types as `TIFFParser`.
///
/// Some tools (macOS export, Lightroom, Capture One) write camera metadata only as XMP. This is not a
/// general XML parser: it collects simple properties written either as elements or as attributes, plus
/// the first item of `rdf:Seq`/`rdf:Bag`/`rdf:Alt` arrays, which covers how these fields are written.
enum XMPParser {
  static func parse(_ data: Data) -> [String: Any] {
    guard let xml = String(data: data, encoding: .utf8) else { return [:] }
    let properties = readProperties(xml)

    var result: [String: Any] = [:]

    // The fields list has the preferred source first, so the first value found wins
    for field in fields where result[field.key] == nil {
      if let raw = properties[field.property], let value = field.kind.convert(raw) {
        result[field.key] = value
      }
    }

    if let flash = flashValue(properties) {
      result["Flash"] = flash
    }

    for (property, key) in [("exif:GPSLatitude", "GPSLatitude"), ("exif:GPSLongitude", "GPSLongitude")] {
      if let raw = properties[property], let coordinate = gpsCoordinate(raw) {
        result[key] = coordinate.value
        result["\(key)Ref"] = coordinate.ref
      }
    }

    // XMP has a full timestamp where EXIF splits off the date
    if let raw = properties["exif:GPSTimeStamp"], let date = exifDate(raw) {
      result["GPSDateStamp"] = String(date.prefix(10))
    }

    return result
  }
}

// MARK: - Field mapping

private enum Kind {
  case string, int, double, date

  func convert(_ raw: String) -> Any? {
    switch self {
      case .string:
        return raw.isEmpty ? nil : raw
      case .int:
        if let value = Int(raw) { return value }
        return rational(raw).map { Int($0.rounded()) }
      case .double:
        return rational(raw)
      case .date:
        return exifDate(raw)
    }
  }
}

private struct Field {
  let property: String
  let key: String
  let kind: Kind
}

/// XMP property (with its canonical namespace prefix) → Scry key. Where several XMP properties map to
/// the same key, the first one listed is preferred.
private let fields: [Field] = [
  // TIFF
  Field(property: "tiff:ImageWidth", key: "ImageWidth", kind: .int),
  Field(property: "tiff:ImageLength", key: "ImageLength", kind: .int),
  Field(property: "tiff:ImageDescription", key: "ImageDescription", kind: .string),
  Field(property: "dc:description", key: "ImageDescription", kind: .string),
  Field(property: "tiff:Make", key: "Make", kind: .string),
  Field(property: "tiff:Model", key: "Model", kind: .string),
  Field(property: "tiff:Orientation", key: "Orientation", kind: .int),
  Field(property: "tiff:XResolution", key: "XResolution", kind: .double),
  Field(property: "tiff:YResolution", key: "YResolution", kind: .double),
  Field(property: "tiff:ResolutionUnit", key: "ResolutionUnit", kind: .int),
  Field(property: "tiff:Software", key: "Software", kind: .string),
  Field(property: "xmp:CreatorTool", key: "Software", kind: .string),
  Field(property: "tiff:DateTime", key: "DateTime", kind: .date),
  Field(property: "xmp:ModifyDate", key: "DateTime", kind: .date),
  Field(property: "tiff:Artist", key: "Artist", kind: .string),
  Field(property: "dc:creator", key: "Artist", kind: .string),
  Field(property: "tiff:Copyright", key: "Copyright", kind: .string),
  Field(property: "dc:rights", key: "Copyright", kind: .string),

  // EXIF
  Field(property: "exif:ExposureTime", key: "ExposureTime", kind: .double),
  Field(property: "exif:FNumber", key: "FNumber", kind: .double),
  Field(property: "exif:ExposureProgram", key: "ExposureProgram", kind: .int),
  Field(property: "exif:ISOSpeedRatings", key: "ISOSpeedRatings", kind: .int),
  Field(property: "exifEX:PhotographicSensitivity", key: "ISOSpeedRatings", kind: .int),
  Field(property: "exif:DateTimeOriginal", key: "DateTimeOriginal", kind: .date),
  Field(property: "photoshop:DateCreated", key: "DateTimeOriginal", kind: .date),
  Field(property: "exif:DateTimeDigitized", key: "DateTimeDigitized", kind: .date),
  Field(property: "xmp:CreateDate", key: "DateTimeDigitized", kind: .date),
  Field(property: "exif:ShutterSpeedValue", key: "ShutterSpeedValue", kind: .double),
  Field(property: "exif:ApertureValue", key: "ApertureValue", kind: .double),
  Field(property: "exif:BrightnessValue", key: "BrightnessValue", kind: .double),
  Field(property: "exif:ExposureBiasValue", key: "ExposureBiasValue", kind: .double),
  Field(property: "exif:MeteringMode", key: "MeteringMode", kind: .int),
  Field(property: "exif:FocalLength", key: "FocalLength", kind: .double),
  Field(property: "exif:OffsetTime", key: "OffsetTime", kind: .string),
  Field(property: "exif:OffsetTimeOriginal", key: "OffsetTimeOriginal", kind: .string),
  Field(property: "exif:OffsetTimeDigitized", key: "OffsetTimeDigitized", kind: .string),
  Field(property: "exif:PixelXDimension", key: "PixelXDimension", kind: .int),
  Field(property: "exif:PixelYDimension", key: "PixelYDimension", kind: .int),
  Field(property: "exif:CustomRendered", key: "CustomRendered", kind: .int),
  Field(property: "exif:ExposureMode", key: "ExposureMode", kind: .int),
  Field(property: "exif:WhiteBalance", key: "WhiteBalance", kind: .int),
  Field(property: "exif:FocalLenIn35mmFilm", key: "FocalLenIn35mmFilm", kind: .int),
  Field(property: "exif:SceneCaptureType", key: "SceneCaptureType", kind: .int),
  Field(property: "exifEX:BodySerialNumber", key: "BodySerialNumber", kind: .string),
  Field(property: "aux:SerialNumber", key: "BodySerialNumber", kind: .string),
  Field(property: "exifEX:LensMake", key: "LensMake", kind: .string),
  Field(property: "exifEX:LensModel", key: "LensModel", kind: .string),
  Field(property: "aux:Lens", key: "LensModel", kind: .string),
  Field(property: "exifEX:LensSerialNumber", key: "LensSerialNumber", kind: .string),
  Field(property: "aux:LensSerialNumber", key: "LensSerialNumber", kind: .string),

  // GPS (latitude, longitude and the date stamp need their own conversion, see `parse`)
  Field(property: "exif:GPSAltitudeRef", key: "GPSAltitudeRef", kind: .int),
  Field(property: "exif:GPSAltitude", key: "GPSAltitude", kind: .double),
  Field(property: "exif:GPSSpeedRef", key: "GPSSpeedRef", kind: .string),
  Field(property: "exif:GPSSpeed", key: "GPSSpeed", kind: .double),
  Field(property: "exif:GPSImgDirectionRef", key: "GPSImgDirectionRef", kind: .string),
  Field(property: "exif:GPSImgDirection", key: "GPSImgDirection", kind: .double),
  Field(property: "exif:GPSDestBearingRef", key: "GPSDestBearingRef", kind: .string),
  Field(property: "exif:GPSDestBearing", key: "GPSDestBearing", kind: .double),
]

/// Namespace URI → the prefix used in `fields`. Files can bind any prefix to these URIs, so properties
/// are matched by namespace, not by the prefix the file happens to use.
private let canonicalPrefixes: [String: String] = [
  "http://ns.adobe.com/tiff/1.0/": "tiff",
  "http://ns.adobe.com/exif/1.0/": "exif",
  "http://cipa.jp/exif/1.0/": "exifEX",
  "http://ns.adobe.com/exif/1.0/aux/": "aux",
  "http://ns.adobe.com/xap/1.0/": "xmp",
  "http://ns.adobe.com/photoshop/1.0/": "photoshop",
  "http://purl.org/dc/elements/1.1/": "dc",
]

// MARK: - Reading properties

private let qualifiedName = #"([A-Za-z_][\w.-]*):([A-Za-z_][\w.-]*)"#
private let namespacePattern = #"xmlns:([A-Za-z_][\w.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')"#
/// prefix:Name="value", as used on rdf:Description
private let attributePattern = qualifiedName + #"\s*=\s*(?:"([^"]*)"|'([^']*)')"#
/// <prefix:Name>value</prefix:Name>
private let elementPattern = "<" + qualifiedName + #"(?:\s[^>]*)?>([^<]*)</\1:\2\s*>"#
/// <prefix:Name><rdf:Seq><rdf:li>value</rdf:li>…, keeping only the first item
private let arrayPattern = "<" + qualifiedName + #"(?:\s[^>]*)?>\s*<[\w.-]+:(?:Seq|Bag|Alt)(?:\s[^>]*)?>\s*<[\w.-]+:li(?:\s[^>]*)?>([^<]*)</"#

/// All simple properties in the packet, keyed by canonical "prefix:Name". The first occurrence wins.
private func readProperties(_ xml: String) -> [String: String] {
  var prefixes: [String: String] = [:]
  for groups in matches(namespacePattern, in: xml) {
    if let prefix = groups[0], let uri = groups[1] ?? groups[2], let canonical = canonicalPrefixes[uri] {
      prefixes[prefix] = canonical
    }
  }

  var properties: [String: String] = [:]

  func add(_ prefix: String?, _ localName: String?, _ value: String?) {
    guard let prefix, let localName, let value, let canonical = prefixes[prefix] else { return }
    let key = "\(canonical):\(localName)"
    let decoded = decodeEntities(value).trimmingCharacters(in: .whitespacesAndNewlines)
    if properties[key] == nil, !decoded.isEmpty {
      properties[key] = decoded
    }
  }

  for groups in matches(attributePattern, in: xml) {
    add(groups[0], groups[1], groups[2] ?? groups[3])
  }
  for groups in matches(elementPattern, in: xml) {
    add(groups[0], groups[1], groups[2])
  }
  for groups in matches(arrayPattern, in: xml) {
    add(groups[0], groups[1], groups[2])
  }

  return properties
}

/// The capture groups of every match of `pattern` in `text`.
private func matches(_ pattern: String, in text: String) -> [[String?]] {
  guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
  let nsText = text as NSString
  return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).map { match in
    (1 ..< match.numberOfRanges).map { index in
      let range = match.range(at: index)
      return range.location == NSNotFound ? nil : nsText.substring(with: range)
    }
  }
}

private func decodeEntities(_ value: String) -> String {
  value
    .replacingOccurrences(of: "&lt;", with: "<")
    .replacingOccurrences(of: "&gt;", with: ">")
    .replacingOccurrences(of: "&quot;", with: "\"")
    .replacingOccurrences(of: "&apos;", with: "'")
    .replacingOccurrences(of: "&#39;", with: "'")
    .replacingOccurrences(of: "&amp;", with: "&")
}

// MARK: - Value conversion

/// "8/1" → 8.0, "341/50" → 6.82, "200" → 200.0
private func rational(_ raw: String) -> Double? {
  let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
  if parts.count == 2, let num = Double(parts[0]), let den = Double(parts[1]) {
    return den == 0 ? 0.0 : num / den
  }
  return Double(raw)
}

/// XMP dates are ISO 8601 ("2026-04-11T13:21:58.000+02:00", or just "2026-04-11");
/// EXIF writes "2026:04:11 13:21:58".
private func exifDate(_ raw: String) -> String? {
  let pattern = #"^(\d{4})[-:](\d{2})[-:](\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?"#
  guard let groups = matches(pattern, in: raw).first,
        let year = groups[0], let month = groups[1], let day = groups[2]
  else { return nil }
  return "\(year):\(month):\(day) \(groups[3] ?? "00"):\(groups[4] ?? "00"):\(groups[5] ?? "00")"
}

/// XMP writes GPS coordinates as "DDD,MM,SSk" or "DDD,MM.mmk" (k is N, S, E or W).
/// EXIF has [degrees, minutes, seconds] plus a separate reference.
private func gpsCoordinate(_ raw: String) -> (value: [Double], ref: String)? {
  guard let ref = raw.last, "NSEW".contains(ref) else { return nil }
  let parts = raw.dropLast().split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }

  switch parts.count {
    case 3:
      return (parts, String(ref))
    case 2:
      let minutes = parts[1].rounded(.down)
      let seconds = ((parts[1] - minutes) * 60 * 1_000_000).rounded() / 1_000_000
      return ([parts[0], minutes, seconds], String(ref))
    default:
      return nil
  }
}

/// XMP spells out the EXIF Flash bit field as a struct of separate properties.
private func flashValue(_ properties: [String: String]) -> Int? {
  guard let fired = properties["exif:Fired"] else { return nil }

  func bool(_ value: String?) -> Bool { value?.lowercased() == "true" }
  func int(_ value: String?) -> Int { value.flatMap { Int($0) } ?? 0 }

  return (bool(fired) ? 0x01 : 0)
    | int(properties["exif:Return"]) << 1
    | int(properties["exif:Mode"]) << 3
    | (bool(properties["exif:Function"]) ? 0x20 : 0)
    | (bool(properties["exif:RedEyeMode"]) ? 0x40 : 0)
}
