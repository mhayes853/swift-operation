import CanIClimbKit
import Foundation
import Testing

@Suite("Schema tests")
struct SchemaTests {
  @Test("Creates Database Successfully")
  func createDatabaseSuccessfully() throws {
    let url = URL.temporaryDirectory.appending(path: "test-\(UUID()).db")

    #expect(throws: Never.self) {
      try canIClimbDatabase(url: url)
    }
    try FileManager.default.removeItem(at: url)
  }
}
