enum TagGroup {
  case tiff, exif, gps
}

// MARK: - IFD0 / TIFF tags

let tiffTags: [UInt16: String] = [
  0x0100: "ImageWidth",
  0x0101: "ImageLength",
  0x010E: "ImageDescription",
  0x010F: "Make",
  0x0110: "Model",
  0x0112: "Orientation",
  0x011A: "XResolution",
  0x011B: "YResolution",
  0x0128: "ResolutionUnit",
  0x0131: "Software",
  0x0132: "DateTime",
  0x013B: "Artist",
  0x013C: "HostComputer",
  0x8298: "Copyright",
]

// MARK: - EXIF sub-IFD tags

let exifTags: [UInt16: String] = [
  0x829A: "ExposureTime",
  0x829D: "FNumber",
  0x8822: "ExposureProgram",
  0x8827: "ISOSpeedRatings",
  0x9000: "ExifVersion",
  0x9003: "DateTimeOriginal",
  0x9004: "DateTimeDigitized",
  0x9201: "ShutterSpeedValue",
  0x9202: "ApertureValue",
  0x9203: "BrightnessValue",
  0x9204: "ExposureBiasValue",
  0x9207: "MeteringMode",
  0x9209: "Flash",
  0x920A: "FocalLength",
  0x9010: "OffsetTime",
  0x9011: "OffsetTimeOriginal",
  0x9012: "OffsetTimeDigitized",
  0xA002: "PixelXDimension",
  0xA003: "PixelYDimension",
  0xA401: "CustomRendered",
  0xA402: "ExposureMode",
  0xA403: "WhiteBalance",
  0xA405: "FocalLenIn35mmFilm",
  0xA406: "SceneCaptureType",
  0xA431: "BodySerialNumber",
  0xA432: "LensSpecification",
  0xA433: "LensMake",
  0xA434: "LensModel",
  0xA435: "LensSerialNumber",
]

// MARK: - GPS sub-IFD tags

let gpsTags: [UInt16: String] = [
  0x0000: "GPSVersionID",
  0x0001: "GPSLatitudeRef",
  0x0002: "GPSLatitude",
  0x0003: "GPSLongitudeRef",
  0x0004: "GPSLongitude",
  0x0005: "GPSAltitudeRef",
  0x0006: "GPSAltitude",
  0x0007: "GPSTimeStamp",
  0x000C: "GPSSpeedRef",
  0x000D: "GPSSpeed",
  0x0010: "GPSImgDirectionRef",
  0x0011: "GPSImgDirection",
  0x0017: "GPSDestBearingRef",
  0x0018: "GPSDestBearing",
  0x001D: "GPSDateStamp",
]

// Special IFD pointer tags (not included in output, used for navigation)
let exifIFDPointer: UInt16 = 0x8769
let gpsIFDPointer: UInt16 = 0x8825

func tagName(for tag: UInt16, group: TagGroup) -> String? {
  switch group {
    case .tiff: tiffTags[tag]
    case .exif: exifTags[tag]
    case .gps: gpsTags[tag]
  }
}
