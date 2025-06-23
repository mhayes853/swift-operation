import Dependencies
import SharingQuery
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
      $0[NumberFactLoaderKey.self] = self.loader
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
      $0[NumberFactLoaderKey.self] = self.loader
      $0.defaultQueryClient = .testInstance()
    } operation: {
      let model = AppModel()

      model.counterAdded()

      let counterModel = model.counters[1]

      XCTAssertEqual(model.counters.count, 2)
      XCTAssertNotNil(model.counters[id: counterModel.id])

      model.counterRemoved(id: counterModel.id)

      XCTAssertEqual(model.counters.count, 1)
      XCTAssertNil(model.counters[id: counterModel.id])
    }
  }

  func test_TotalSum() async throws {
    let expectedFact = NumberFact(number: 1050, content: "This is a really cool fact")
    self.loader.contents[expectedFact.number] = expectedFact.content

    try await withDependencies {
      $0[NumberFactLoaderKey.self] = self.loader
      $0.defaultQueryClient = .testInstance()
    } operation: {
      let model = AppModel()

      model.counterAdded()

      model.counters[1].jumped(to: 1000)
      model.counters[0].jumped(to: 50)

      let counterModel = model.summedCounter()

      XCTAssertEqual(counterModel.count, 1050)

      _ = try? await counterModel.$fact.activeTasks.first?.runIfNeeded()
      _ = try? await counterModel.$nthPrime.activeTasks.first?.runIfNeeded()

      XCTAssertEqual(counterModel.fact, expectedFact)
      XCTAssertEqual(counterModel.nthPrime, 8387)
    }
  }
}
