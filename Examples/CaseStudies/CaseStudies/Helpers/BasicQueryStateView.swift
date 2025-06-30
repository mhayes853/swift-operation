import SwiftUI
import Query

struct BasicQueryStateView<State: QueryStateProtocol, Content: View>: View
where State.StateValue == State.StatusValue? {
  let state: State
  @ViewBuilder let content: (State.StatusValue) -> Content
  
  var body: some View {
    switch self.state.status {
    case let .result(.success(value)):
      self.content(value)
      
    case let .result(.failure(error)):
      Text(error.localizedDescription).foregroundStyle(.red)
      
    default:
      if let value = self.state.currentValue {
        self.content(value)
          .opacity(0.5)
      } else {
        ProgressView()
      }
    }
  }
}

struct BasicInfiniteQueryStateView<State: _InfiniteQueryStateProtocol, Content: View>: View {
  let state: State
  @ViewBuilder let content: (State.StatusValue) -> Content
  
  var body: some View {
    switch self.state.status {
    case let .result(.success(value)):
      self.content(value)
      
    case let .result(.failure(error)):
      Text(error.localizedDescription).foregroundStyle(.red)
      
    default:
      if !self.state.currentValue.isEmpty {
        self.content(self.state.currentValue)
          .opacity(0.5)
      } else {
        ProgressView()
      }
    }
  }
}

