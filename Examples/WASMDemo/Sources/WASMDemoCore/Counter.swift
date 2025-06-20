import SharingQuery
import SwiftNavigation
import Observation
import JavaScriptKit

// MARK: - CounterModel

@MainActor
@Observable
public final class CounterModel {
  @ObservationIgnored
  @SharedQuery<NumberFact.Query.State> public var fact: NumberFact?

  @ObservationIgnored
  @SharedQuery<NumberFact.NthPrimeQuery.State> public var nthPrime: Int??

  public private(set) var count: Int

  public init(startingAt number: Int = 0) {
    self.count = number
    self._fact = SharedQuery(wrappedValue: nil, NumberFact.query(for: number))
    self._nthPrime = SharedQuery(wrappedValue: nil, NumberFact.nthPrimeQuery(for: number))
  }
}

extension CounterModel {
  public func incremented() {
    self.jumped(to: self.count + 1)
  }

  public func decremented() {
    self.jumped(to: self.count - 1)
  }
}

extension CounterModel {
  public func jumped(to number: Int) {
    self.count = number
    self._fact = SharedQuery(wrappedValue: nil, NumberFact.query(for: number))
    self._nthPrime = SharedQuery(wrappedValue: nil, NumberFact.nthPrimeQuery(for: number))
  }
}

// MARK: - Render Counter

@MainActor
private var tokens = Set<ObserveToken>()

@MainActor
public func renderCounter(using model: CounterModel, in container: JSObject) {
  observe {
  
  }
  .store(in: &tokens)
}