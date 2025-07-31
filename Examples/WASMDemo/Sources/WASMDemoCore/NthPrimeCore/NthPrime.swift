import Dependencies
import Foundation
import Query

// MARK: - NthPrime

public func nthPrime(for n: Int) -> Int? {
  guard n > 0 else { return nil }

  let upperBound = n < 6 ? 15 : Int(Double(n) * log(Double(n)) + Double(n) * log(log(Double(n))))

  var isPrime = [Bool](repeating: true, count: upperBound + 1)
  isPrime[0] = false
  isPrime[1] = false

  for i in 2...Int(Double(upperBound).squareRoot()) {
    if isPrime[i] {
      for multiple in stride(from: i * i, through: upperBound, by: i) {
        isPrime[multiple] = false
      }
    }
  }

  var count = 0
  for (index, isPrime) in isPrime.enumerated() {
    guard isPrime else { continue }
    count += 1
    if count == n {
      return index
    }
  }
  return nil
}

// MARK: - Nth Prime Query

extension Int {
  public static func nthPrimeQuery(
    for number: Int
  ) -> some QueryRequest<Int?, NthPrimeQuery.State> {
    // NB: Calculating the prime number doesn't need the network, but it still takes
    // significant time to complete for larger numbers.
    NthPrimeQuery(number: number)
      .completelyOffline()
      .disableApplicationActiveRefetching()
      .taskConfiguration {
        @Dependency(WebWorkerTaskExecutorKey.self) var executor
        $0.name = "Nth prime for \(number)"
        $0.executorPreference = executor
      }
  }

  public struct NthPrimeQuery: QueryRequest, Hashable {
    let number: Int

    public func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<Int?>
    ) async throws -> Int? {
      await nthPrime(for: self.number)
    }
  }
}
