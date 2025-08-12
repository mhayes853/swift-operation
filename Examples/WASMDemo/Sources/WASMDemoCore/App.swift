import Dependencies
import IdentifiedCollections
import JavaScriptKit
import Observation
import SwiftNavigation

// MARK: - AppModel

@MainActor
@Observable
public final class AppModel {
  public private(set) var counters: IdentifiedArrayOf<CounterModel> {
    didSet { self.bind() }
  }

  public init() {
    self.counters = [CounterModel(startingAt: 0)]
  }

  public func summedCounter() -> CounterModel {
    let sum = self.counters.reduce(into: 0) { $0 += $1.count }
    return CounterModel(startingAt: sum)
  }

  public func counterAdded() {
    self.counters.append(CounterModel(startingAt: 0))
  }

  public func allCleared() {
    self.counters.removeAll()
  }

  private func bind() {
    for counter in self.counters {
      counter.onRemoved = { [weak self, weak counter] in
        guard let self, let counter else { return }
        self.counters.remove(id: counter.id)
      }
    }
  }
}

// MARK: - Render App

@MainActor
public func renderApp(model: AppModel, in container: JSObject) {
  let title = document.createElement!("h1")
  title.innerText = "WASM Demo"

  let description = document.createElement!("p")
  description.innerText = """
    This is a sample browser app built using Swift Query and WASM. You can add and \
    remove counters to see some cool facts about numbers!

    The top counter displays the sum of all the counters, and you can also see your \
    connection status to the internet in real-time.
    """

  _ = container.appendChild!(title)
  _ = container.appendChild!(description)

  renderNetworkStatusIndicator(in: container)

  let sumContainer = document.createElement!("div")
  _ = container.appendChild!(sumContainer)

  let addCounterButton = document.createElement!("button")
  addCounterButton.innerText = "Add Counter"
  addCounterButton.onclick = .object(
    JSClosure { [weak model] _ in
      model?.counterAdded()
      return .undefined
    }
  )
  _ = container.appendChild!(addCounterButton)

  let clearAllButton = document.createElement!("button")
  clearAllButton.innerText = "Clear All Counters"
  clearAllButton.onclick = .object(
    JSClosure { [weak model] _ in
      model?.allCleared()
      return .undefined
    }
  )
  _ = container.appendChild!(clearAllButton)

  let countersContainer = document.createElement!("div")
  _ = container.appendChild!(countersContainer)

  var currentSummedCounter: CounterModel?
  var previousCounterIds = Set<CounterModel.ID>()
  observe { [weak model] in
    guard let model else { return }

    if let currentSummedCounter {
      cleanupCounter(for: currentSummedCounter.id)
    }
    let summedModel = model.summedCounter()
    currentSummedCounter = summedModel
    renderCounter(title: "Total Sum", using: summedModel, in: sumContainer.object!) { _, _ in }

    for id in previousCounterIds where model.counters[id: id] == nil {
      cleanupCounter(for: id)
    }
    for counter in model.counters where !previousCounterIds.contains(counter.id) {
      renderCounter(using: counter, in: countersContainer.object!)
    }
    previousCounterIds = Set(model.counters.ids)
  }
  .store(in: &tokens)
}

@MainActor
private var tokens = Set<ObserveToken>()
