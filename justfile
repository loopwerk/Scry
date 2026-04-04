build:
  swift build

test:
  swift test

test-linux:
  docker run --rm -v "$(pwd):/package" -w /package swift:6.0 swift test

format:
  swiftformat -swift-version 6 .
