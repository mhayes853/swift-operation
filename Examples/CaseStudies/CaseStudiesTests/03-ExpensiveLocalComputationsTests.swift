import CustomDump
import Testing

@testable import CaseStudies

@MainActor
@Suite("ExpensiveLocalComputations tests")
struct ExpensiveLocalComputationsTests {
  @Test("No 0th Prime Number")
  func no0thPrimeNumber() async throws {
    let model = ExpensiveLocalComputationModel()
    _ = await model.$nthPrime.activeTasks.first?.runIfNeeded()
    expectNoDifference(model.nthPrime, .some(nil))
  }

  @Test("Jumping to Count Loads Nth Prime Number")
  func jumpingToCountLoadsNthPrimeNumber() async throws {
    let model = ExpensiveLocalComputationModel()
    _ = await model.$nthPrime.activeTasks.first?.runIfNeeded()

    model.count = 1_000_000
    _ = await model.$nthPrime.activeTasks.first?.runIfNeeded()

    expectNoDifference(model.nthPrime, 15_485_863)
  }
}
