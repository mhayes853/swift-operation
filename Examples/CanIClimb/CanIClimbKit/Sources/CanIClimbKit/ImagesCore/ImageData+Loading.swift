import CryptoKit
import Dependencies
import Foundation
import Operation

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

// MARK: - Query

extension ImageData {
  public static func query(for url: URL) -> some QueryRequest<Self, any Error> {
    Query(url: url).staleWhenNoValue()
      .taskConfiguration { $0.name = "Fetch image for \(url)" }
  }

  public struct Query: QueryRequest, Hashable {
    let url: URL

    public func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<ImageData, any Error>
    ) async throws -> ImageData {
      @Dependency(ImageData.LoaderKey.self) var loader
      return try await loader.image(for: self.url)
    }
  }
}
