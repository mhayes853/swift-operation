import Foundation
import JavaScriptKit
import Observation
import SharingQuery
import SwiftNavigation

// MARK: - CounterModel

@MainActor
@Observable
public final class CounterModel: Identifiable {
  @ObservationIgnored
  @SharedQuery<NumberFact.Query.State> public var fact: NumberFact?

  @ObservationIgnored
  @SharedQuery<Int.NthPrimeQuery.State> public var nthPrime: Int??

  public private(set) var count: Int

  @ObservationIgnored public var onRemoved: (() -> Void)?

  public init(startingAt number: Int = 0) {
    self.count = number
    self._fact = SharedQuery(NumberFact.query(for: number))
    self._nthPrime = SharedQuery(Int.nthPrimeQuery(for: number))
  }

  public func incremented() {
    self.jumped(to: self.count + 1)
  }

  public func decremented() {
    self.jumped(to: self.count - 1)
  }

  public func jumped(to number: Int) {
    self.count = number
    self.$fact = SharedQuery(NumberFact.query(for: number))
    self.$nthPrime = SharedQuery(Int.nthPrimeQuery(for: number))
  }

  public func removed() {
    self.onRemoved?()
  }
}

// MARK: - Render Counter

@MainActor
public func renderCounter(
  title: String = "Count",
  using model: CounterModel,
  in container: JSObject,
  renderControls: @MainActor (CounterModel, JSObject) -> Void = renderCounterControls
) {
  let counterContainer = document.createElement!("div").object!
  counterContainer.id = .string(model.id.counterElementId)
  _ = container.appendChild!(counterContainer)

  renderCounterLabels(title: title, using: model, in: counterContainer)
  renderControls(model, counterContainer)
}

// MARK: - Render Controls

@MainActor
public func renderCounterControls(using model: CounterModel, in container: JSObject) {
  let increment = document.createElement!("button")
  increment.innerText = "Increment"
  increment.onclick = .object(
    JSClosure { [weak model] _ in
      model?.incremented()
      return .undefined
    }
  )
  _ = container.appendChild!(increment)

  let decrement = document.createElement!("button")
  decrement.innerText = "Decrement"
  decrement.onclick = .object(
    JSClosure { [weak model] _ in
      model?.decremented()
      return .undefined
    }
  )
  _ = container.appendChild!(decrement)

  renderJumpButton(for: 100, using: model, in: container)
  renderJumpButton(for: 1000, using: model, in: container)
  renderJumpButton(for: 10_000, using: model, in: container)
  renderJumpButton(for: 100_000, using: model, in: container)
  renderJumpButton(for: 1_000_000, using: model, in: container)

  let remove = document.createElement!("button")
  remove.innerText = "Remove"
  remove.style.backgroundColor = .string("red")
  remove.style.color = .string("white")
  remove.onclick = .object(
    JSClosure { [weak model] _ in
      model?.removed()
      return .undefined
    }
  )
  _ = container.appendChild!(remove)
}

// MARK: - Render Jump Button

@MainActor
private func renderJumpButton(
  for number: Int,
  using model: CounterModel,
  in container: JSObject
) {
  let jump = document.createElement!("button")
  jump.innerText = .string("Jump to \(number)")
  jump.onclick = .object(
    JSClosure { [weak model] _ in
      model?.jumped(to: number)
      return .undefined
    }
  )
  _ = container.appendChild!(jump)
}

// MARK: - Render Counter Labels

@MainActor
private func renderCounterLabels(
  title: String,
  using model: CounterModel,
  in container: JSObject
) {
  let countLabel = document.createElement!("h3")
  let factLabel = document.createElement!("p")
  let nthPrimeLabel = document.createElement!("p")

  _ = container.appendChild!(countLabel)
  _ = container.appendChild!(factLabel)
  _ = container.appendChild!(nthPrimeLabel)

  let token = observe { [weak model] in
    guard let model else { return }

    countLabel.innerText = .string("\(title) \(model.count)")

    switch model.$fact.status {
    case .result(.success(let fact)):
      factLabel.innerText = .string(fact.content)
      factLabel.style.color = "black"

    case .result(.failure(let error)):
      factLabel.innerText = .string("Error: \(error.localizedDescription)")
      factLabel.style.color = "red"

    default:
      factLabel.innerText = .string(model.fact?.content ?? "Loading Fact...")
      factLabel.style.color = "gray"
    }

    if let prime = model.nthPrime {
      if let prime {
        nthPrimeLabel.innerText = .string(
          "The \(model.count.nthFormatted) prime number is \(prime)!"
        )
      } else {
        nthPrimeLabel.innerText = .string("There is no \(model.count.nthFormatted) prime number...")
      }
      nthPrimeLabel.style.color = "black"
    } else {
      nthPrimeLabel.innerText = .string("Loading \(model.count.nthFormatted) prime number...")
      nthPrimeLabel.style.color = "gray"
    }
  }
  tokens[model.id] = token
}

// MARK: - Cleanup Counter

@MainActor
public func cleanupCounter(for id: CounterModel.ID) {
  tokens.removeValue(forKey: id)
  if let container = document.getElementById!(id.counterElementId).object {
    _ = container.remove!()
  }
}

// MARK: - CounterModel Element ID

extension ObjectIdentifier {
  fileprivate var counterElementId: String {
    "counter-\(self)"
  }
}

// MARK: - Tokens

@MainActor
private var tokens = [CounterModel.ID: ObserveToken]()
