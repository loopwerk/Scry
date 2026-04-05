# Scry

A pure Swift EXIF metadata parser. No dependencies, no Apple frameworks. Fully macOS and Linux compatible.

Supports **JPEG**, **PNG**, and **WebP** images. 

Scry does not load the entire image into memory, and as such can be used with large image files.

## Usage

```swift
import Scry

if let metadata = try? Scry.metadata(fromFileAt: "/path/to/photo.jpg") {
  print(metadata["Make"])    // "Apple"
  print(metadata["Model"])   // "iPhone 14 Pro"
  print(metadata["FNumber"]) // 1.78
}
```

Returns `nil` when the image has no EXIF data.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/loopwerk/Scry.git", from: "1.0.0"),
]
```

## Metadata properties

`Scry.metadata(fromFileAt:)` returns a flat `[String: Any]` dictionary. The keys and value types are:

### Image info (from TIFF IFD0)

| Key | Type | Example |
|-----|------|---------|
| `ImageWidth` | `Int` | `4032` |
| `ImageLength` | `Int` | `3024` |
| `ImageDescription` | `String` | `"Sunset photo"` |
| `Make` | `String` | `"Apple"` |
| `Model` | `String` | `"iPhone 14 Pro"` |
| `Orientation` | `Int` | `1` |
| `XResolution` | `Double` | `72.0` |
| `YResolution` | `Double` | `72.0` |
| `ResolutionUnit` | `Int` | `2` |
| `Software` | `String` | `"18.7.3"` |
| `DateTime` | `String` | `"2026:01:05 17:11:42"` |
| `Artist` | `String` | `"Kevin Renskers"` |
| `HostComputer` | `String` | `"iPhone 14 Pro"` |
| `Copyright` | `String` | `"2026 Kevin Renskers"` |

### Exposure and camera (from EXIF sub-IFD)

| Key | Type | Example |
|-----|------|---------|
| `ExposureTime` | `Double` | `0.04` (seconds) |
| `FNumber` | `Double` | `1.78` |
| `ExposureProgram` | `Int` | `2` |
| `ISOSpeedRatings` | `Int` | `800` |
| `ExifVersion` | `[UInt8]` | `[2, 3, 2]` |
| `DateTimeOriginal` | `String` | `"2026:01:05 17:11:42"` |
| `DateTimeDigitized` | `String` | `"2026:01:05 17:11:42"` |
| `ShutterSpeedValue` | `Double` | `4.64` (APEX) |
| `ApertureValue` | `Double` | `1.66` (APEX) |
| `BrightnessValue` | `Double` | `-2.50` (APEX) |
| `ExposureBiasValue` | `Double` | `0.0` (EV) |
| `MeteringMode` | `Int` | `5` |
| `Flash` | `Int` | `16` |
| `FocalLength` | `Double` | `6.86` (mm) |
| `OffsetTime` | `String` | `"+01:00"` |
| `OffsetTimeOriginal` | `String` | `"+01:00"` |
| `OffsetTimeDigitized` | `String` | `"+01:00"` |
| `PixelXDimension` | `Int` | `4032` |
| `PixelYDimension` | `Int` | `3024` |
| `CustomRendered` | `Int` | `0` |
| `ExposureMode` | `Int` | `0` |
| `WhiteBalance` | `Int` | `0` |
| `FocalLenIn35mmFilm` | `Int` | `24` |
| `SceneCaptureType` | `Int` | `0` |
| `BodySerialNumber` | `String` | `"DNXXXXXXXXXXXX"` |
| `LensSpecification` | `[Double]` | `[2.22, 9.0, 1.78, 2.8]` |
| `LensMake` | `String` | `"Apple"` |
| `LensModel` | `String` | `"iPhone 14 Pro back triple camera 6.86mm f/1.78"` |
| `LensSerialNumber` | `String` | `"XXXXXXXXXX"` |

### GPS (from GPS sub-IFD)

| Key | Type | Example |
|-----|------|---------|
| `GPSVersionID` | `[Int]` | `[2, 3, 0, 0]` |
| `GPSLatitudeRef` | `String` | `"N"` |
| `GPSLatitude` | `[Double]` | `[52.0, 31.0, 12.74]` (deg, min, sec) |
| `GPSLongitudeRef` | `String` | `"E"` |
| `GPSLongitude` | `[Double]` | `[13.0, 24.0, 36.33]` (deg, min, sec) |
| `GPSAltitudeRef` | `Int` | `0` (0 = above sea level) |
| `GPSAltitude` | `Double` | `38.39` (meters) |
| `GPSTimeStamp` | `[Double]` | `[16.0, 11.0, 42.0]` (hrs, min, sec) |
| `GPSSpeedRef` | `String` | `"K"` (km/h) |
| `GPSSpeed` | `Double` | `0.0` |
| `GPSImgDirectionRef` | `String` | `"T"` (true north) |
| `GPSImgDirection` | `Double` | `139.56` (degrees) |
| `GPSDestBearingRef` | `String` | `"T"` |
| `GPSDestBearing` | `Double` | `139.56` (degrees) |
| `GPSDateStamp` | `String` | `"2026:01:05"` |

Only keys present in the image are included in the dictionary. Not every image will have every property.
