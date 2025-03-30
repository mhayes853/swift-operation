import Perception
import QueryCore

public final class QueryModel<State: QueryStateProtocol>: Perceptible, Observable {
  public private(set) var state: State

  public let store: QueryStore<State>

  public init(store: QueryStore<State>) {
    self.store = store
    self.state = store.state
  }
}
