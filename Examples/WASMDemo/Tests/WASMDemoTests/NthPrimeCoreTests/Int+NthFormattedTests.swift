import WASMDemoCore
import XCTest

final class IntNthFormattedTests: XCTestCase {
  func test_basics() {
    let pairs = [
      (0, "0th"),
      (1, "1st"),
      (2, "2nd"),
      (3, "3rd"),
      (4, "4th"),
      (11, "11th"),
      (12, "12th"),
      (13, "13th"),
      (32, "32nd"),
      (43, "43rd"),
      (501, "501st")
    ]
    for (i, expected) in pairs {
      XCTAssertEqual(i.nthFormatted, expected)
    }
  }
}
