import SharingQuery
import SwiftNavigation
import Observation
import JavaScriptKit
import Foundation

// MARK: - CounterModel

@MainActor
@Observable
public final class CounterModel: Identifiable {
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
  var counterContainer = document.createElement!("div")
  container.appendChild!(counterContainer)

  renderCounterLabels(title: "Count", using: model, in: counterContainer.object!)

  let increment = document.createElement!("button")
  increment.innerText = "Increment"
  increment.onclick = .object(
    JSClosure { _ in 
      model.incremented()
      return .undefined
    }
  )
  container.appendChild!(increment)

  let decrement = document.createElement!("button")
  decrement.innerText = "Decrement"
  decrement.onclick = .object(
    JSClosure { _ in 
      model.decremented()
      return .undefined
    }
  )
  container.appendChild!(decrement)

  let jump100 = document.createElement!("button")
  jump100.innerText = "Jump to 100"
  jump100.onclick = .object(
    JSClosure { _ in 
      model.jumped(to: 100)
      return .undefined
    }
  )
  container.appendChild!(jump100)

  let jump1000 = document.createElement!("button")
  jump1000.innerText = "Jump to 1000"
  jump1000.onclick = .object(
    JSClosure { _ in 
      model.jumped(to: 1000)
      return .undefined
    }
  )
  container.appendChild!(jump1000)

  let jump10000 = document.createElement!("button")
  jump10000.innerText = "Jump to 10,000"
  jump10000.onclick = .object(
    JSClosure { _ in 
      model.jumped(to: 10_000)
      return .undefined
    }
  )
  container.appendChild!(jump10000)
}

@MainActor
public func renderCounterLabels(
  title: String,
  using model: CounterModel, 
  in container: JSObject
) {
  var countLabel = document.createElement!("h3")
  var factLabel = document.createElement!("p")
  var nthPrimeLabel = document.createElement!("p")

  container.appendChild!(countLabel)
  container.appendChild!(factLabel)
  container.appendChild!(nthPrimeLabel)

  observe {
    countLabel.innerText = .string("\(title) \(model.count)")

    switch model.$fact.status {
    case let .result(.success(fact)):
      factLabel.innerText = .string(fact.content)
      factLabel.style.color = "black"
    
    case let .result(.failure(error)):
      factLabel.innerText = .string("Error: \(error.localizedDescription)")
      factLabel.style.color = "red"

    default:
      factLabel.innerText = .string(model.fact?.content ?? "Loading Fact...")
      factLabel.style.color = "gray"
    }

    if let prime = model.nthPrime {
      if let prime {
        nthPrimeLabel.innerText = .string("The \(model.count.nthFormatted) prime number is \(prime)!")
      } else {
        nthPrimeLabel.innerText = .string("There is no \(model.count.nthFormatted) prime number...")
      }
      nthPrimeLabel.style.color = "black"
    } else {
      nthPrimeLabel.innerText = .string("Loading \(model.count.nthFormatted) prime number...")
      nthPrimeLabel.style.color = "gray"
    }
  }
  .store(in: &tokens)
}
