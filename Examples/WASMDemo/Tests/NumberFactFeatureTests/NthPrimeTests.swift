import XCTest
import NumberFactFeature

final class NthPrimeNumberTests: XCTestCase {
  func test_basics() async {
    let nums = [
      (-10, nil), 
      (0, nil), 
      (1, 2), 
      (40, 173), 
      (100, 541),
      (1000, 7919)
    ]
    await withTaskGroup(of: Void.self) { group in
      for (nth, expected) in nums {
        group.addTask {
          let num = await nthPrime(for: nth)
          XCTAssertEqual(num, expected)
        }
      }
      await group.waitForAll()
    }
  }
}