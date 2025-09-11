import Foundation

// MARK: - Request

extension NumericHealthSamples {
  public struct Request: Hashable, Sendable {
    public let interval: DateInterval

    public init(interval: DateInterval) {
      self.interval = interval
    }
  }
}

// MARK: - Loader

extension NumericHealthSamples {
  public protocol Loader {
    func samples(from request: Request) async throws -> NumericHealthSamples
  }
}
