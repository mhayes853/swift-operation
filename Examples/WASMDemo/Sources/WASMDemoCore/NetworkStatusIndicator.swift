import SharingQuery
import JavaScriptKit
import SwiftNavigation

@MainActor
private var tokens = Set<ObserveToken>()

@MainActor
public func renderNetworkStatusIndicator(in container: JSObject) {
  @SharedReader(.networkStatus) var status = .connected

  let label = document.createElement!("b")
  _ = container.appendChild!(label)

  observe {
    // NB: The browser doesn't return a "requiresConnection" status, so treat it as disconnected.
    switch status {
    case .connected:
      label.innerText = "Network Status: Connected"
    default:
      label.innerText = "Network Status: Disconnected"
    }
  }
  .store(in: &tokens)
}