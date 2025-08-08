import SharingQuery
import SwiftUI

public struct RemoteQueryStateView<
  State: QueryStateProtocol,
  Content: View
>: View where State.StateValue == State.StatusValue? {
  private let shared: SharedQuery<State>
  private let content: (State.StatusValue) -> Content

  public init(
    _ shared: SharedQuery<State>,
    @ViewBuilder content: @escaping (State.StatusValue) -> Content
  ) {
    self.shared = shared
    self.content = content
  }

  public var body: some View {
    switch self.shared.status {
    case .result(.success(let value)):
      self.content(value)
    case .result(.failure(let error)):
      if case let value? = self.shared.wrappedValue {
        self.content(value)
      } else {
        RemoteOperationErrorView(error: error) {
          Task { try await self.shared.fetch() }
        }
      }
    default:
      if case let value? = self.shared.wrappedValue {
        self.content(value)
      } else {
        SpinnerView()
      }
    }
  }
}
