import WASMDemoCore
import XCTest

final class NthPrimeNumberTests: XCTestCase {
  func test_basics() {
    let nums = [
      (-10, nil),
      (0, nil),
      (1, 2),
      (40, 173),
      (100, 541),
      (1000, 7919)
    ]

    for (nth, expected) in nums {
      XCTAssertEqual(nthPrime(for: nth), expected)
    }
  }
}
