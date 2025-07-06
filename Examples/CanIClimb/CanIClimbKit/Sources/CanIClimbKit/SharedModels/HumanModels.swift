import SwiftUI

// MARK: - HumanActivityLevel

public enum HumanActivityLevel: String, Hashable, Sendable, CaseIterable {
  case sedentary
  case somewhatActive
  case active
  case veryActive
}

extension HumanActivityLevel {
  public var localizedString: LocalizedStringKey {
    switch self {
    case .sedentary: "Sedentary"
    case .somewhatActive: "Somewhat Active"
    case .active: "Active"
    case .veryActive: "Very Active"
    }
  }
}

// MARK: - HumanAgeRange

public enum HumanAgeRange: String, Hashable, Sendable, CaseIterable {
  case under20
  case in20s
  case in30s
  case in40s
  case in50sOrGreater
}

extension HumanAgeRange {
  public var localizedString: LocalizedStringKey {
    switch self {
    case .under20: "Under 20"
    case .in20s: "20s"
    case .in30s: "30s"
    case .in40s: "40s"
    case .in50sOrGreater: "50s or greater"
    }
  }
}

// MARK: - HumanBMI

public struct HumanBMI: Hashable, Sendable {
  public let score: Double

  public init(score: Double) {
    self.score = score
  }
}

extension HumanBMI {
  public init(weight: Measurement<UnitMass>, height: HumanHeight) {
    let meters = height.metric.measurement.converted(to: .meters)
    self.score = weight.converted(to: .kilograms).value / (meters.value * meters.value)
  }
}

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

// MARK: - HumanGender

public enum HumanGender: String, Hashable, Sendable, CaseIterable {
  case male
  case female
  case nonBinary
}

extension HumanGender {
  public var localizedString: LocalizedStringKey {
    switch self {
    case .male: "Male"
    case .female: "Female"
    case .nonBinary: "Non-binary"
    }
  }
}

extension HumanGender {
  public struct Averages: Hashable, Sendable {
    public let weight: Measurement<UnitMass>
    public let height: HumanHeight
  }

  public var averages: Averages {
    switch self {
    case .male: Averages(weight: .averageMale, height: .averageMale)
    case .female: Averages(weight: .averageFemale, height: .averageFemale)
    case .nonBinary: Averages(weight: .averageNonBinary, height: .averageNonBinary)
    }
  }
}

// MARK: - HumanWorkoutFrequency

public enum HumanWorkoutFrequency: String, Hashable, Sendable, CaseIterable {
  case noDays
  case onceOrTwicePerWeek
  case everyOtherDay
  case mostDays
  case everyDay
}

extension HumanWorkoutFrequency {
  public var localizedString: LocalizedStringKey {
    switch self {
    case .noDays: "Never"
    case .onceOrTwicePerWeek: "1-2 Times per Week"
    case .everyOtherDay: "Every Other Day"
    case .mostDays: "Most Days"
    case .everyDay: "Every Day"
    }
  }
}

// MARK: - HumanHeight

public enum HumanHeight: Codable, Hashable, Sendable {
  public struct Imperial: Hashable, Codable, Sendable {
    public let feet: Int
    public let inches: Int

    public init(feet: Int, inches: Int) {
      self.feet = feet
      self.inches = inches
    }
  }

  public struct Metric: Hashable, Codable, Sendable {
    public let centimeters: Double

    public init(centimeters: Double) {
      self.centimeters = centimeters
    }
  }

  case imperial(Imperial)
  case metric(Metric)
}

extension HumanHeight.Imperial {
  public var measurement: Measurement<UnitLength> {
    Measurement(value: Double(feet) + Double(inches) / .inchesPerFoot, unit: .feet)
  }
}

extension HumanHeight.Imperial {
  public var formatted: String {
    "\(self.feet) ft \(self.inches) in"
  }
}

extension HumanHeight.Imperial {
  public static let options: [Self] = {
    var options = [Self]()
    for feet in 0...8 {
      for inches in 0...11 {
        options.append(Self(feet: feet, inches: inches))
      }
    }
    return options
  }()
}

extension HumanHeight {
  public var imperial: Imperial {
    get {
      switch self {
      case .imperial(let imperial):
        return imperial
      case .metric(let metric):
        let feet = metric.centimeters / .feetToCentimeters
        let inches = Int(((feet - Double(Int(feet))) * .inchesPerFoot).rounded())
        return Imperial(feet: Int(feet), inches: inches)
      }
    }
    set { self = .imperial(newValue) }
  }
}

extension HumanHeight.Metric {
  public var measurement: Measurement<UnitLength> {
    Measurement(value: self.centimeters, unit: .centimeters)
  }
}

extension HumanHeight.Metric {
  public var formatted: String {
    "\(Int(self.centimeters)) cm"
  }
}

extension HumanHeight.Metric {
  public static let options = (0...250).map { Self(centimeters: Double($0)) }
}

extension HumanHeight {
  public var metric: Metric {
    get {
      switch self {
      case .imperial(let imperial):
        Metric(centimeters: ceil(imperial.measurement.converted(to: .centimeters).value))
      case .metric(let metric):
        metric
      }
    }
    set { self = .metric(newValue) }
  }
}

// MARK: - Constants

extension HumanHeight {
  public static let averageMale = Self.imperial(Imperial(feet: 5, inches: 8))
  public static let averageFemale = Self.imperial(Imperial(feet: 5, inches: 3))
  public static let averageNonBinary = Self.imperial(Imperial(feet: 5, inches: 5))
}

extension Measurement<UnitMass> {
  public static let averageMale = Measurement(value: 188, unit: .pounds)
  public static let averageFemale = Measurement(value: 168, unit: .pounds)
  public static let averageNonBinary = Measurement(value: 177, unit: .pounds)
}

extension Double {
  fileprivate static let feetToCentimeters = 30.48
  fileprivate static let inchesPerFoot = 12.0
}
