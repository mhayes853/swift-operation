import Dependencies
import Foundation
import SQLiteData
import SharingOperation
import StructuredQueries

// MARK: - Query

extension Mountain {
  public static func query(id: Mountain.ID) -> some QueryRequest<Mountain?, any Error> {
    Self.$query(with: id).stale(after: .fiveMinutes)
  }

  @QueryRequest(path: .custom { (id: Mountain.ID) in .mountain(with: id) })
  private static func query(
    with id: Mountain.ID,
    continuation: OperationContinuation<Mountain?, any Error>
  ) async throws -> Mountain? {
    let catalog = Dependency(Mountain.CatalogKey.self).wrappedValue

    async let mountain = catalog.mountain(with: id)
    if let localMountain = try await catalog.localMountain(with: id) {
      continuation.yield(localMountain)
    }
    return try await mountain
  }
}

extension OperationPath {
  public static let mountain = Self("mountain")

  public static func mountain(with id: Mountain.ID) -> Self {
    .mountain.appending(id)
  }
}
