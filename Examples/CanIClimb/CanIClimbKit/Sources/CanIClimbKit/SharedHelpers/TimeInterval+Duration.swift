import Foundation

extension TimeInterval {
  public init(duration: Duration) {
    let convertedAttoseconds = TimeInterval(duration.components.attoseconds) / 1e18
    self = TimeInterval(duration.components.seconds) + convertedAttoseconds
  }
}
