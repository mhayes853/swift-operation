import AuthenticationServices
import IssueReporting
import Observation
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - SignInModel

@MainActor
@Observable
public final class SignInModel {
  @ObservationIgnored
  @SharedQuery(User.signInMutation, animation: .bouncy) public var signIn: Void?

  public var destination: Destination?

  @ObservationIgnored public var onSignInSuccess: (() -> Void)?

  public init() {}
}

extension SignInModel {
  public func credentialsReceived(
    _ credentials: Result<User.SignInCredentials?, any Error>
  ) async throws {
    guard let credentials = try credentials.get() else {
      self.destination = .alert(.signInFailure)
      return
    }
    try await self.$signIn.mutate(with: User.SignInMutation.Arguments(credentials: credentials))
    self.onSignInSuccess?()
  }
}

extension SignInModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case alert(AlertState<Never>)
  }
}

// MARK: - SignInButton

public struct SignInButton: View {
  let label: SignInWithAppleButton.Label
  @Bindable var model: SignInModel

  public var body: some View {
    SignInWithAppleButton(
      self.label,
      onRequest: { $0.requestedScopes = [.fullName] },
      onCompletion: { result in
        Task {
          await withErrorReporting {
            try await self.model.credentialsReceived(
              result.map(User.SignInCredentials.init(authorization:))
            )
          }
        }
      }
    )
    .alert(self.$model.destination.alert)
  }
}

#Preview {
  SignInButton(label: .continue, model: SignInModel())
    .observeQueryAlerts()
}
