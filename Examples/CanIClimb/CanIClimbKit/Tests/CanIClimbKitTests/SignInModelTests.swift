import CanIClimbKit
import CustomDump
import Dependencies
import DependenciesTestSupport
import SharingOperation
import Synchronization
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite(
    "SignInModel tests",
    .dependencies {
      $0.defaultNetworkObserver = MockNetworkObserver()
    }
  )
  struct SignInModelTests {
    @Test("Successful Sign In")
    func successfulSignIn() async throws {
      let authenticator = User.MockAuthenticator()
      authenticator.requiredCredentials = .mock1

      try await withDependencies {
        $0[User.AuthenticatorKey.self] = authenticator
        $0[User.CurrentLoaderKey.self] = User.MockCurrentLoader(result: .success(.user(.mock1)))
      } operation: {
        let model = SignInModel()
        let onSuccessCount = Mutex(0)
        model.onSignInSuccess = { onSuccessCount.withLock { $0 += 1 } }

        try await model.credentialsReceived(.success(.mock1))
        onSuccessCount.withLock { expectNoDifference($0, 1) }
      }
    }

    @Test("Unsuccessful Sign In, Nil Credentials")
    func unsuccessfulSignInNilCredentials() async throws {
      try await withDependencies {
        $0[User.AuthenticatorKey.self] = User.MockAuthenticator()
      } operation: {
        let model = SignInModel()

        try await model.credentialsReceived(.success(nil))
        expectNoDifference(model.destination, .alert(.signInFailure))
      }
    }

    @Test("Unsuccessful Sign In, Error Credentials")
    func unsuccessfulSignInErrorCredentials() async throws {
      try await withDependencies {
        $0[User.AuthenticatorKey.self] = User.MockAuthenticator()
      } operation: {
        struct SomeError: Error {}
        let model = SignInModel()

        try await model.credentialsReceived(.failure(SomeError()))
        expectNoDifference(model.destination, .alert(.signInFailure))
      }
    }

    @Test("Unsuccessful Sign In, Doesn't Call On Success")
    func unsuccessfulSignInDoesntCallOnSuccess() async throws {
      let authenticator = User.MockAuthenticator()
      authenticator.requiredCredentials = .mock1

      await withDependencies {
        $0[User.AuthenticatorKey.self] = authenticator
        $0[User.CurrentLoaderKey.self] = User.MockCurrentLoader(result: .success(.user(.mock1)))
      } operation: {
        let model = SignInModel()
        let onSuccessCount = Mutex(0)
        model.onSignInSuccess = { onSuccessCount.withLock { $0 += 1 } }

        try? await model.credentialsReceived(.success(.mock2))
        onSuccessCount.withLock { expectNoDifference($0, 0) }
      }
    }
  }
}
