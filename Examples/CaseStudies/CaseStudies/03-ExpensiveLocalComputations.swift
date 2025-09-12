import SharingOperation
import SwiftUI

// MARK: - ExpensiveLocalComputationsCaseStudy

struct ExpensiveLocalComputationsCaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Expensive Local Computations"
  let description: LocalizedStringKey = """
    Some parts of your application may run entirely local on the user's device, but may be \
    computationally expensive. Examples of this include running a large query on a SQLite \
    database, processing a large file, streaming a response from the FoundationModels framework, \
    or simply just calculating a long-running mathematical computation. These examples, while \
    entirely local would still benefit from being made into queries due to their long runtimes.

    You can use the `completelyOffline` modifier to signify that your query runs without a network \
    connection. This will prevent it from being refetched when the user's network flips from \
    offline to online. Additionally, if your query is just a computationally expensive pure \
    function, you'll also want to add on the `disableApplicationActiveRerunning` modifier to \
    prevent the computation from re-running when the user foregrounds your app.
    
    For bonus points, though not implemented in this case study, you can use the \
    `taskConfiguration` modifier to customize the `TaskExecutor` preference of the computation to \
    run on a custom executor.

    Calculating the Nth prime number is fast for smaller numbers, but it gets slower for larger \
    numbers. Try playing around with the counter!
    """

  @State private var model = ExpensiveLocalComputationModel()

  private let counts = [0, 10, 100, 1000, 10_000, 100_000, 1_000_000, 10_000_000]

  var content: some View {
    Stepper(value: self.$model.count) {
      Text("Count \(self.model.count)")
    }
    VStack {
      if self.model.$nthPrime.isLoading {
        ProgressView()
      } else if let nthPrime = self.model.nthPrime {
        let formatted =
          NumberFormatter.ordinal.string(from: self.model.count as NSNumber) ?? "Unknown"
        if let nthPrime {
          Text("The \(formatted) prime number is \(nthPrime).")
        } else {
          Text("There is no \(formatted) prime number.")
        }
      }
    }
    .bold()
    ForEach(self.counts, id: \.self) { count in
      Button("Jump to \(count)") {
        self.model.count = count
      }
    }
  }
}

extension NumberFormatter {
  fileprivate static let ordinal: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .ordinal
    return formatter
  }()
}

// MARK: - ExpensiveLocalComputationModel

@Observable
@MainActor
final class ExpensiveLocalComputationModel {
  var count = 0 {
    didSet {
      self.$nthPrime = SharedOperation(Int.nthPrimeQuery(for: self.count))
    }
  }

  @ObservationIgnored
  @SharedOperation(Int.nthPrimeQuery(for: 0)) var nthPrime
}

// MARK: - Nth Prime

extension Int {
  static func nthPrimeQuery(for n: Int) -> some QueryRequest<Int?, any Error> {
    NthPrimeQuery(n: n)
      .completelyOffline()
      .disableApplicationActiveRerunning()
  }

  struct NthPrimeQuery: QueryRequest, Hashable {
    let n: Int

    func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<Int?, any Error>
    ) async throws -> Int? {
      nthPrime(for: self.n)
    }
  }
}

func nthPrime(for n: Int) -> Int? {
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

// MARK: - Preview

#Preview {
  NavigationStack {
    ExpensiveLocalComputationsCaseStudy()
  }
}
