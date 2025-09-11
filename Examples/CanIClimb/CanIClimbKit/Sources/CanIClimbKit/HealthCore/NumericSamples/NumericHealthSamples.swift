import Foundation

// MARK: - NumericHealthSamples

public struct NumericHealthSamples: Hashable, Sendable {
  public var kind: Kind
  public var elements: [Element]

  public init(kind: Kind, elements: [Element]) {
    self.kind = kind
    self.elements = elements
  }
}

// MARK: - Element

extension NumericHealthSamples {
  public struct Element: Hashable, Sendable {
    public let timestamp: Date
    public let value: Double

    public init(timestamp: Date, value: Double) {
      self.timestamp = timestamp
      self.value = value
    }
  }
}

// MARK: - Kind

extension NumericHealthSamples {
  public enum Kind: Sendable {
    case stepCount
    case vo2Max
    case distanceWalkingRunningMeters
  }
}
