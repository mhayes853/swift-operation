import Foundation

// MARK: - TimeInterval

extension TimeInterval {
  public init(duration: Duration) {
    let convertedAttoseconds = TimeInterval(duration.components.attoseconds) / 1e18
    self = TimeInterval(duration.components.seconds) + convertedAttoseconds
  }
}

// MARK: - Durations

extension Duration {
  public static let fiveMinutes = Duration.seconds(5 * 60)
}
