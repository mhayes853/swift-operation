import Dependencies
import SharingOperation
import SwiftUINavigation

extension AlertState {
  public static func remoteOperationError(
    title: () -> TextState,
    message: @escaping () -> TextState
  ) -> Self {
    Self {
      title()
    } message: {
      @SharedReader(.networkStatus) var status = NetworkConnectionStatus.connected
      switch status {
      case .connected:
        return message()
      default:
        return TextState("Please check your internet connection.")
      }
    }
  }
}
