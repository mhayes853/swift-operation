import AuthenticationServices
import Observation
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - SignInModel

@MainActor
@Observable
public final class SignInModel {
  @ObservationIgnored
  @SharedReader(.networkStatus) private var networkStatus = NetworkConnectionStatus.connected

  @ObservationIgnored
  @SharedQuery(User.signInMutation, animation: .bouncy) public var signIn: Void?

  public var destination: Destination?

  @ObservationIgnored public var onSignInSuccess: (() -> Void)?

  public init() {}
}

extension SignInModel {
  public func credentialsReceived(_ credentials: Result<User.SignInCredentials?, any Error>) async {
    do {
      guard let credentials = try credentials.get() else {
        self.destination = .alert(.signInFailure(for: .generic))
        return
      }
      try await self.$signIn.mutate(with: User.SignInMutation.Arguments(credentials: credentials))
      self.destination = .alert(.signInSuccess)
      self.onSignInSuccess?()
    } catch {
      self.destination = .alert(
        .signInFailure(for: self.networkStatus != .connected ? .noConnection : .generic)
      )
    }
  }
}

extension SignInModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case alert(AlertState<AlertAction>)
  }
}

// MARK: - AlertState

extension SignInModel {
  public enum AlertAction: Hashable, Sendable {}

  public enum FailureReason: Hashable, Sendable {
    case noConnection
    case generic
  }
}

extension AlertState where Action == SignInModel.AlertAction {
  public static let signInSuccess = Self {
    TextState("Success")
  } message: {
    TextState("You've signed in successfully. Enjoy climbing!")
  }

  public static func signInFailure(for reason: SignInModel.FailureReason) -> Self {
    Self {
      TextState("An Error Occurred")
    } message: {
      switch reason {
      case .noConnection: TextState("Please check your internet connection.")
      case .generic: TextState("Something went wrong. Please try again later.")
      }
    }
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
          await self.model.credentialsReceived(
            result.map(User.SignInCredentials.init(authorization:))
          )
        }
      }
    )
    .alert(self.$model.destination.alert) { _ in }
  }
}

#Preview {
  SignInButton(label: .continue, model: SignInModel())
}
