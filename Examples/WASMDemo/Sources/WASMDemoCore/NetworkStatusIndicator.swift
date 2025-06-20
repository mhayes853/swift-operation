import SharingQuery
import JavaScriptKit
import SwiftNavigation

@MainActor
private var tokens = Set<ObserveToken>()

@MainActor
public func renderNetworkStatusIndicator(in container: JSObject) {
  @Shared(.networkStatus) var status

  observe {
  
  }
  .store(in: &tokens)
}