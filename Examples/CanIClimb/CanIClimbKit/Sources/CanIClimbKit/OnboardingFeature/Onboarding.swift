import Observation
import SwiftUI

// MARK: - OnboardingModel

@MainActor
@Observable
public final class OnboardingModel {
  @ObservationIgnored
  public var onFinished: (() -> Void)?

  public var path = [Path]()

  public init() {}
}

// MARK: - Path

extension OnboardingModel {
  public enum Path: Hashable, Sendable {
    case selectGender
    case selectAgeRange
    case selectHeight
    case selectWeight
    case selectActivityLevel
    case selectWorkoutFrequency
    case connectHealthKit
    case shareLocation
    case wrapUp
  }
}

// MARK: - OnboardingView

public struct OnboardingView: View {
  @Bindable var model: OnboardingModel

  public var body: some View {
    NavigationStack(path: self.$model.path) {
      EmptyView()
    }
  }
}
