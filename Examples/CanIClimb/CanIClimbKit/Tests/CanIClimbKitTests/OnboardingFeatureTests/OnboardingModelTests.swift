import CanIClimbKit
import CustomDump
import DependenciesTestSupport
import Testing

@MainActor
@Suite("OnboardingModel tests", .dependency(\.defaultDatabase, try! canIClimbDatabase()))
struct OnboardingModelTests {
  @Test("Full Onboarding Flow")
  func fullOnboardingFlow() {
  }
}
