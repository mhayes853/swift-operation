import CustomDump
import Foundation
import Operation
import Testing

@Suite("OperationBackoffFunction tests")
struct OperationBackoffFunctionTests {
  @Test(
    "Exponential",
    arguments: [(0, 0), (1, 1000), (2, 2000), (3, 4000), (4, 8000), (5, 16000)]
  )
  func exponential(n: Int, e: TimeInterval) {
    let function = OperationBackoffFunction.exponential(1000)
    expectNoDifference(function(n), e)
  }

  @Test(
    "Linear",
    arguments: [(0, 0), (1, 1000), (2, 2000), (3, 3000), (4, 4000), (5, 5000)]
  )
  func linear(n: Int, e: TimeInterval) {
    let function = OperationBackoffFunction.linear(1000)
    expectNoDifference(function(n), e)
  }

  @Test("Fibonacci", arguments: [(0, 0), (1, 1000), (2, 1000), (3, 2000), (4, 3000), (5, 5000)])
  func fibonacci(n: Int, e: TimeInterval) {
    let function = OperationBackoffFunction.fibonacci(1000)
    expectNoDifference(function(n), e)
  }

  @Test("Jittered Selects Random Value Based On Generator")
  func jitterUsesDifferentValuesForExponential() {
    let function = OperationBackoffFunction.exponential(1000).jittered(using: ZeroRandomGenerator())
    expectNoDifference(function(10), 0)
  }

  @Test(
    "CustomStringConvertible",
    arguments: [
      (OperationBackoffFunction { _ in 10 }, "Custom"),
      (OperationBackoffFunction("Blob") { _ in 10 }, "Blob"),
      (.linear(10), "Linear every 10.0 secs"),
      (.exponential(1), "Exponential every 1.0 sec"),
      (.constant(2).jittered(), "Constant 2.0 secs with jitter")
    ]
  )
  func customStringConvertibleWithBackoffFunction(
    function: OperationBackoffFunction,
    string: String
  ) {
    expectNoDifference(function.description, "OperationBackoffFunction(\(string))")
  }
}

private struct ZeroRandomGenerator: RandomNumberGenerator {
  func next() -> UInt64 {
    0
  }
}
