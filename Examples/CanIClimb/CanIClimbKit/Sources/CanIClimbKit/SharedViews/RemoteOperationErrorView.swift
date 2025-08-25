import SharingOperation
import SwiftUI

public struct RemoteOperationErrorView: View {
  @Environment(\.colorScheme) private var colorScheme
  @SharedReader(.networkStatus) private var networkStatus = .connected

  private let error: any Error
  private let onRetry: () -> Void

  public init(error: any Error, onRetry: @escaping () -> Void) {
    self.error = error
    self.onRetry = onRetry
  }

  public var body: some View {
    VStack {
      Text("An Error Occurred")
        .font(.title3.bold())
      Group {
        if self.networkStatus != .connected {
          Text("Check your internet connection and try again.")
        } else {
          Text(error.localizedDescription)
        }
      }
      .multilineTextAlignment(.center)
      Button("Retry") {
        self.onRetry()
      }
      .bold()
      .buttonStyle(.borderedProminent)
      .tint(self.colorScheme == .light ? .primary : .secondaryBackground)
    }
  }
}
