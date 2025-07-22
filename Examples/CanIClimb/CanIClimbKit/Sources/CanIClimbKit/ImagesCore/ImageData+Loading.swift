import CryptoKit
import Dependencies
import Foundation
import Query

// MARK: - Loader

extension ImageData {
  public protocol Loader: Sendable {
    func localImage(for url: URL) async throws -> ImageData?
    func remoteImage(for url: URL) async throws -> ImageData
  }

  public enum LoaderKey: DependencyKey {
    public static let liveValue: any Loader = ImageData.FileSystemCachedLoader.shared
  }
}

extension ImageData.Loader {
  public func image(for url: URL) async throws -> ImageData {
    if let local = try? await self.localImage(for: url) {
      return local
    }
    return try await self.remoteImage(for: url)
  }
}

// MARK: - FileSystemCachedLoader

extension ImageData {
  public final actor FileSystemCachedLoader {
    private let directoryURL: URL
    private let transport: any HTTPDataTransport
    private let fileManager = FileManager.default

    public init(directoryURL: URL, transport: any HTTPDataTransport) {
      self.directoryURL = directoryURL
      self.transport = transport
    }
  }
}

extension ImageData.FileSystemCachedLoader {
  public static let shared = ImageData.FileSystemCachedLoader(
    directoryURL: .cachesDirectory.appending(path: "images"),
    transport: URLSession.shared
  )
}

extension ImageData.FileSystemCachedLoader: ImageData.Loader {
  public func localImage(for url: URL) async throws -> ImageData? {
    guard let data = try? Data(contentsOf: self.localURL(for: url)) else { return nil }
    return try ImageData(data: (data as NSData).decompressed(using: .lzfse) as Data)
  }

  public func remoteImage(for url: URL) async throws -> ImageData {
    let (data, _) = try await self.transport.data(for: URLRequest(url: url))
    let image = try ImageData(data: data)
    try self.saveLocalImage(for: url, image: image)
    return image
  }

  private func saveLocalImage(for url: URL, image: ImageData) throws {
    try self.ensureDirectory()
    try (image.data as NSData).compressed(using: .lzfse)
      .write(to: self.localURL(for: url), options: [.atomicWrite])
  }

  private func localURL(for remoteURL: URL) -> URL {
    let hash = SHA256.hash(data: Data(remoteURL.absoluteString.utf8))
    let filename = hash.compactMap { String(format: "%02x", $0) }.joined()
    return self.directoryURL.appending(path: "image-\(filename)")
  }

  private func ensureDirectory() throws {
    try FileManager.default.createDirectory(
      at: self.directoryURL,
      withIntermediateDirectories: true
    )
  }
}

// MARK: - Query

extension ImageData {
  public static func query(for url: URL) -> some QueryRequest<Self, Query.State> {
    Query(url: url).staleWhenNoValue()
      .taskConfiguration { $0.name = "Fetch image for \(url)" }
  }

  public struct Query: QueryRequest, Hashable {
    let url: URL

    public func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<ImageData>
    ) async throws -> ImageData {
      @Dependency(ImageData.LoaderKey.self) var loader
      return try await loader.image(for: self.url)
    }
  }
}
