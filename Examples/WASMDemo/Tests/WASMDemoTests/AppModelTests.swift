import Dependencies
import SharingOperation
import WASMDemoCore
import XCTest

@MainActor
final class AppModelTests: XCTestCase, @unchecked Sendable {
  private let loader = NumberFact.MockLoader()

  override func setUp() async throws {
    try await super.setUp()
    await MainActor.run {
      self.loader.contents[0] = ""
    }
  }

  func test_AppendsCounter() async throws {
    let expectedFact = NumberFact(number: 0, content: "This is a cool fact")
    self.loader.contents[expectedFact.number] = expectedFact.content

    try await withDependencies {
      $0[NumberFact.LoaderKey.self] = self.loader
      $0.defaultQueryClient = .testInstance()
    } operation: {
      let model = AppModel()
      model.counterAdded()

      let counterModel = model.counters[1]

      _ = try await counterModel.$fact.activeTasks.first?.runIfNeeded()
      _ = try await counterModel.$nthPrime.activeTasks.first?.runIfNeeded()

      XCTAssertEqual(counterModel.fact, expectedFact)
      XCTAssertEqual(counterModel.nthPrime, .some(nil))
    }
  }

  func test_RemovesCounter() {
    withDependencies {
      $0[NumberFact.LoaderKey.self] = self.loader
      $0.defaultQueryClient = .testInstance()
    } operation: {
      let model = AppModel()

      model.counterAdded()

      let counterModel = model.counters[1]

      XCTAssertEqual(model.counters.count, 2)
      XCTAssertNotNil(model.counters[id: counterModel.id])

      counterModel.removed()

      XCTAssertEqual(model.counters.count, 1)
      XCTAssertNil(model.counters[id: counterModel.id])
    }
  }

  func test_TotalSumCounter() async throws {
    let expectedFact1 = NumberFact(number: 1050, content: "This is a really cool fact")
    let expectedFact2 = NumberFact(number: 50, content: "This is another really cool fact")
    self.loader.contents[expectedFact1.number] = expectedFact1.content
    self.loader.contents[expectedFact2.number] = expectedFact2.content

    try await withDependencies {
      $0[NumberFact.LoaderKey.self] = self.loader
      $0.defaultQueryClient = .testInstance()
    } operation: {
      let model = AppModel()

      model.counterAdded()

      model.counters[1].jumped(to: 1000)
      model.counters[0].jumped(to: 50)

      var summedModel = model.summedCounter()

      XCTAssertEqual(summedModel.count, 1050)
      _ = try? await summedModel.$fact.activeTasks.first?.runIfNeeded()
      _ = try? await summedModel.$nthPrime.activeTasks.first?.runIfNeeded()
      XCTAssertEqual(summedModel.fact, expectedFact1)
      XCTAssertEqual(summedModel.nthPrime, 8387)

      model.counters[1].removed()

      summedModel = model.summedCounter()

      XCTAssertEqual(summedModel.count, 50)
      _ = try? await summedModel.$fact.activeTasks.first?.runIfNeeded()
      _ = try? await summedModel.$nthPrime.activeTasks.first?.runIfNeeded()
      XCTAssertEqual(summedModel.fact, expectedFact2)
      XCTAssertEqual(summedModel.nthPrime, 229)
    }
  }

  func test_ClearsAll() async throws {
    try await withDependencies {
      $0[NumberFact.LoaderKey.self] = self.loader
      $0.defaultQueryClient = .testInstance()
    } operation: {
      let model = AppModel()

      model.counterAdded()
      model.counterAdded()

      XCTAssertEqual(model.counters.count, 3)

      model.allCleared()
      XCTAssertEqual(model.counters.count, 0)
      XCTAssertEqual(model.summedCounter().count, 0)
    }
  }
}
