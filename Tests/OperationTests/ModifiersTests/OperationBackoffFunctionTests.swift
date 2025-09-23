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
    let function = OperationBackoffFunction.exponential(.milliseconds(1000))
    expectNoDifference(function(n), .milliseconds(e))
  }

  @Test(
    "Linear",
    arguments: [(0, 0), (1, 1000), (2, 2000), (3, 3000), (4, 4000), (5, 5000)]
  )
  func linear(n: Int, e: TimeInterval) {
    let function = OperationBackoffFunction.linear(.milliseconds(1000))
    expectNoDifference(function(n), .milliseconds(e))
  }

  @Test("Fibonacci", arguments: [(0, 0), (1, 1000), (2, 1000), (3, 2000), (4, 3000), (5, 5000)])
  func fibonacci(n: Int, e: TimeInterval) {
    let function = OperationBackoffFunction.fibonacci(.milliseconds(1000))
    expectNoDifference(function(n), .milliseconds(e))
  }

  @Test("Jittered Selects Random Value Based On Generator")
  func jitterUsesDifferentValuesForExponential() {
    let function = OperationBackoffFunction.exponential(.milliseconds(1000))
      .jittered(using: LCRNG(seed: 1))
    let duration = function(10)
    expectNoDifference(duration.components.seconds, 79)
    expectNoDifference(duration.components.attoseconds, 639_051_702_710_521_372)
  }

  @Test(
    "CustomStringConvertible",
    arguments: [
      (OperationBackoffFunction { _ in .seconds(10) }, "Custom"),
      (OperationBackoffFunction("Blob") { _ in .seconds(10) }, "Blob"),
      (.linear(.seconds(10)), "Linear every 10.0 seconds"),
      (.exponential(.seconds(1)), "Exponential every 1.0 seconds"),
      (.constant(.seconds(2)).jittered(), "Constant 2.0 seconds with jitter")
    ]
  )
  func customStringConvertibleWithBackoffFunction(
    function: OperationBackoffFunction,
    string: String
  ) {
    expectNoDifference(function.description, "OperationBackoffFunction(\(string))")
  }
}

private struct LCRNG: RandomNumberGenerator {
  var seed: UInt64

  mutating func next() -> UInt64 {
    self.seed = 2_862_933_555_777_941_757 &* self.seed &+ 3_037_000_493
    return self.seed
  }
}
