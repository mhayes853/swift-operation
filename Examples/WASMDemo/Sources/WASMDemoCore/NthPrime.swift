import Foundation

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
