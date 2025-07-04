import Foundation

// MARK: - HumanBMI

public struct HumanBMI: Hashable, Sendable {
  public let score: Double

  public init(score: Double) {
    self.score = score
  }
}

// MARK: - Calculated

extension HumanBMI {
  public init(weight: Measurement<UnitMass>, height: HumanHeight) {
    let meters = height.metric.measurement.converted(to: .meters)
    print(meters, height)
    self.score = weight.converted(to: .kilograms).value / (meters.value * meters.value)
  }
}

// MARK: - Score Quality

extension HumanBMI {
  public enum ScoreQuality: Hashable, Sendable {
    case underweight
    case normal
    case overweight
    case obese
  }

  public var quality: ScoreQuality {
    switch score {
    case ..<18.5: .underweight
    case 18.5..<25: .normal
    case 25..<30: .overweight
    default: .obese
    }
  }
}
