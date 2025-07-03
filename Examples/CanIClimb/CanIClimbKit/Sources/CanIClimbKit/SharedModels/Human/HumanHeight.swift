import Foundation

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

// MARK: - Imperial

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

// MARK: - Metric

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

extension Double {
  fileprivate static let feetToCentimeters = 30.48
  fileprivate static let inchesPerFoot = 12.0
}
