import SwiftNavigation
import Observation
import JavaScriptKit
import IdentifiedCollections
import Dependencies

// MARK: - AppModel

@MainActor
@Observable
public final class AppModel {
  public private(set) var counters: IdentifiedArrayOf<CounterModel>

  public init() {
    self.counters = [CounterModel(startingAt: 0)]
  }
}

extension AppModel {
  public func summedCounter() -> CounterModel {
    let count = self.counters.reduce(into: 0) { $0 += $1.count }
    return CounterModel(startingAt: count)
  }
}

extension AppModel {
  public func counterAdded() {
    self.counters.append(CounterModel(startingAt: 0))
  }
}

extension AppModel {
  public func counterRemoved(id: CounterModel.ID) {
    self.counters.remove(id: id)
  }
}

// MARK: - Render App

@MainActor
private var tokens = Set<ObserveToken>()

@MainActor
public func renderApp(model: AppModel, in container: JSObject) {
  var title = document.createElement!("h1")
  title.innerText = "WASM Demo"

  var description = document.createElement!("p")
  description.innerText = """
    This is a sample browser app built using Swift Query and WASM. You can add and \
    remove counters to see some cool facts about numbers!

    The top counter displays the sum of all the counters, and you can also see your \ 
    connection status to the internet in real-time.
    """

  container.appendChild!(title)
  container.appendChild!(description)

  renderNetworkStatusIndicator(in: container)

  var sumContainer = document.createElement!("div")
  container.appendChild!(sumContainer)

  var addCounterButton = document.createElement!("button")
  addCounterButton.innerText = "Add Counter"
  addCounterButton.onclick = .object(
    JSClosure { _ in
      model.counterAdded()
      return .undefined
    }
  )
  container.appendChild!(addCounterButton)

  var countersContainer = document.createElement!("div")
  container.appendChild!(countersContainer)

  observe {
    sumContainer.innerHTML = ""
    renderCounterLabels(
      title: "Total Sum", 
      using: model.summedCounter(), 
      in: sumContainer.object!
    )

    countersContainer.innerHTML = ""
    for counter in model.counters {
      renderCounter(using: counter, in: countersContainer.object!)
    }
  }
  .store(in: &tokens)
}