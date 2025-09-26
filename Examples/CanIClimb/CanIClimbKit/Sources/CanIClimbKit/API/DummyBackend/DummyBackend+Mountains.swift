import Foundation
import IdentifiedCollections
import Logging

// MARK: - Mountains

extension DummyBackend {
  final actor Mountains {
    private var mountains: [Mountain]?

    func mountains(
      for request: Mountain.SearchRequest,
      plannedIds: Set<Mountain.ID>
    ) async throws -> Mountain.SearchResult {
      let allMatching = try await self.downloadIfNeeded()
        .filter {
          request.search.text.isEmpty || $0.name.localizedStandardContains(request.search.text)
        }
        .filter { request.search.category != .planned || plannedIds.contains($0.id) }
      let startIndex = request.page * 10
      let endIndex = min(allMatching.count, startIndex + 10)
      guard startIndex < allMatching.count else {
        return Mountain.SearchResult(
          mountains: IdentifiedArray(uniqueElements: []),
          hasNextPage: false
        )
      }
      return Mountain.SearchResult(
        mountains: IdentifiedArray(uniqueElements: allMatching[startIndex..<endIndex]),
        hasNextPage: endIndex < allMatching.count
      )
    }

    func mountain(for id: Mountain.ID) async throws -> Mountain? {
      try await self.downloadIfNeeded().first { $0.id == id }
    }

    private func downloadIfNeeded() async throws -> [Mountain] {
      if let mountains {
        return mountains
      }
      let (data, _) = try await URLSession.shared.data(from: .mountains)
      self.mountains = try JSONDecoder().decode([Mountain].self, from: data)
      currentLogger.info("Downloaded \(self.mountains!.count) mountains!")
      return self.mountains!
    }
  }
}

// MARK: - URL

extension URL {
  fileprivate static let mountains = Self(
    string: "https://whypeople.xyz/json-files/caniclimb-mountains.json"
  )!
}
