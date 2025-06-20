import XCTest
import WASMDemoCore
import SharingQuery
import Dependencies

@MainActor
final class CounterModelTests: XCTestCase {
  private let loader = NumberFact.MockLoader()

  func test_LoadsQueriesForInitialNumber() async throws {
    let expectedFact = NumberFact(number: 100, content: "This is a cool fact") 
    self.loader.contents[expectedFact.number] = expectedFact.content

    try await withDependencies {
      $0[NumberFactLoaderKey.self] = self.loader
      $0.defaultQueryClient = .testInstance()
    } operation: {
      let model = CounterModel(startingAt: 100)
    
      _ = try await model.$fact.activeTasks.first?.runIfNeeded()
      _ = try await model.$nthPrime.activeTasks.first?.runIfNeeded()

      XCTAssertEqual(model.fact, expectedFact)
      XCTAssertEqual(model.nthPrime, 541)
    }
  }

  func test_IncrementUpdatesQueriesForNewCount() async throws {
    let expectedFact = NumberFact(number: 100, content: "This is a cool fact") 
    self.loader.contents[expectedFact.number] = expectedFact.content
    self.loader.contents[99] = ""

    try await withDependencies {
      $0[NumberFactLoaderKey.self] = self.loader
      $0.defaultQueryClient = .testInstance()
    } operation: {
      let model = CounterModel(startingAt: 99)

      _ = try await model.$fact.activeTasks.first?.runIfNeeded()
      _ = try await model.$nthPrime.activeTasks.first?.runIfNeeded()

      XCTAssertEqual(model.count, 99)
      model.incremented()
      XCTAssertEqual(model.count, 100)

      _ = try await model.$fact.activeTasks.first?.runIfNeeded()
      _ = try await model.$nthPrime.activeTasks.first?.runIfNeeded()

      XCTAssertEqual(model.fact, expectedFact)
      XCTAssertEqual(model.nthPrime, 541)
    }
  }

  func test_DecrementUpdatesQueriesForNewCount() async throws {
    let expectedFact = NumberFact(number: 100, content: "This is a cool fact") 
    self.loader.contents[expectedFact.number] = expectedFact.content
    self.loader.contents[101] = ""

    try await withDependencies {
      $0[NumberFactLoaderKey.self] = self.loader
      $0.defaultQueryClient = .testInstance()
    } operation: {
      let model = CounterModel(startingAt: 101)

      _ = try await model.$fact.activeTasks.first?.runIfNeeded()
      _ = try await model.$nthPrime.activeTasks.first?.runIfNeeded()

      XCTAssertEqual(model.count, 101)
      model.decremented()
      XCTAssertEqual(model.count, 100)

      _ = try await model.$fact.activeTasks.first?.runIfNeeded()
      _ = try await model.$nthPrime.activeTasks.first?.runIfNeeded()

      XCTAssertEqual(model.fact, expectedFact)
      XCTAssertEqual(model.nthPrime, 541)
    }
  }

  func test_JumpedUpdatesQueriesForNewCount() async throws {
    let expectedFact = NumberFact(number: 100, content: "This is a cool fact") 
    self.loader.contents[expectedFact.number] = expectedFact.content
    self.loader.contents[0] = ""
    
    try await withDependencies {
      $0[NumberFactLoaderKey.self] = self.loader
      $0.defaultQueryClient = .testInstance()
    } operation: {
      let model = CounterModel(startingAt: 0)

      _ = try await model.$fact.activeTasks.first?.runIfNeeded()
      _ = try await model.$nthPrime.activeTasks.first?.runIfNeeded()

      XCTAssertEqual(model.count, 0)
      model.jumped(to: 100)
      XCTAssertEqual(model.count, 100)

      _ = try await model.$fact.activeTasks.first?.runIfNeeded()
      _ = try await model.$nthPrime.activeTasks.first?.runIfNeeded()

      XCTAssertEqual(model.fact, expectedFact)
      XCTAssertEqual(model.nthPrime, 541)
    }
  }
}