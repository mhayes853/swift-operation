import AuthenticationServices
import Dependencies
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
    guard let credentials = try? credentials.get() else {
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
  @Environment(\.signInButtonMockCredentials) var mockCredentials
  @Environment(\.colorScheme) var colorScheme

  public var body: some View {
    SignInWithAppleButton(
      self.label,
      onRequest: { $0.requestedScopes = [.fullName] },
      onCompletion: { result in
        Task {
          await withErrorReporting {
            if let mockCredentials {
              try await self.model.credentialsReceived(.success(mockCredentials))
            } else {
              try await self.model.credentialsReceived(
                result.map(User.SignInCredentials.init(authorization:))
              )
            }
          }
        }
      }
    )
    .signInWithAppleButtonStyle(self.colorScheme == .dark ? .white : .black)
    .alert(self.$model.destination.alert)
  }
}

// MARK: - Environment

extension EnvironmentValues {
  @Entry public var signInButtonMockCredentials: User.SignInCredentials?
}

#Preview {
  let _ = prepareDependencies {
    let authenticator = User.MockAuthenticator()
    authenticator.requiredCredentials = .mock1
    $0.defaultDatabase = try! canIClimbDatabase()
    $0.defaultQueryClient = QueryClient(storeCreator: .canIClimb)
    $0[User.AuthenticatorKey.self] = authenticator
    $0[User.CurrentLoaderKey.self] = User.MockCurrentLoader(result: .success(.mock1))
  }

  SignInButton(label: .continue, model: SignInModel())
    .frame(maxHeight: 60)
    .padding()
    .environment(\.signInButtonMockCredentials, .mock1)
    .observeQueryAlerts()
}
