import CanIClimbKit
import CustomDump
import Foundation
import Testing

@MainActor
@Suite("ImageData+FileSystemCachedLoader tests")
final class ImageDataFileSystemCachedLoaderTests {
  private let directoryURL = URL.temporaryDirectory.appending(path: "images-\(UUID())")

  deinit {
    try? FileManager.default.removeItem(at: self.directoryURL)
  }

  @Test("No Cached Image When Nothing Loaded")
  func noCachedImageWhenNothingLoaded() async throws {
    let loader = ImageData.FileSystemCachedLoader(
      directoryURL: self.directoryURL,
      transport: .throwing
    )
    let image = try await loader.localImage(for: .image1)
    expectNoDifference(image, nil)
  }

  @Test("Loads Remote Image From URL")
  func loadsImageFromURL() async throws {
    let loader = ImageData.FileSystemCachedLoader(
      directoryURL: self.directoryURL,
      transport: .mock { request in
        guard request.url == .image1 else { return (400, .data(Data())) }
        return (200, .data(await ImageData.circle.data))
      }
    )
    let image = try await loader.remoteImage(for: .image1)
    expectNoDifference(image, .circle)
  }

  @Test("Caches Remotely Loaded Images")
  func cachesRemotelyLoadedImages() async throws {
    let loader = ImageData.FileSystemCachedLoader(
      directoryURL: self.directoryURL,
      transport: .mock { request in
        guard request.url == .image1 else { return (400, .data(Data())) }
        return (200, .data(await ImageData.circle.data))
      }
    )
    _ = try await loader.remoteImage(for: .image1)
    let image = try await loader.localImage(for: .image1)
    expectNoDifference(image, .circle)
  }

  @Test("Caches For Separate Keys")
  func cachesForSeparateKeys() async throws {
    let loader = ImageData.FileSystemCachedLoader(
      directoryURL: self.directoryURL,
      transport: .mock { request in
        if request.url == .image1 {
          (200, .data(await ImageData.circle.data))
        } else {
          (200, .data(await ImageData.rectangle.data))
        }
      }
    )
    _ = try await loader.remoteImage(for: .image1)
    var image1 = try await loader.localImage(for: .image1)
    expectNoDifference(image1, .circle)

    var image2 = try await loader.localImage(for: .image2)
    expectNoDifference(image2, nil)

    _ = try await loader.remoteImage(for: .image2)
    image2 = try await loader.localImage(for: .image2)
    expectNoDifference(image2, .rectangle)

    image1 = try await loader.localImage(for: .image1)
    expectNoDifference(image1, .circle)
  }
}

extension URL {
  fileprivate static let image1 = Self(string: "https://www.somewhere.com/image?name=test1.png")!
  fileprivate static let image2 = Self(string: "https://www.somewhere.com/image?name=test2.png")!
}
