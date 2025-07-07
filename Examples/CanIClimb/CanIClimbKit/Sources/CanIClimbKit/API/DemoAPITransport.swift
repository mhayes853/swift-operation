import Foundation

public final class DemoAPITransport: HTTPDataTransport {
  public init() {}

  public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await self.randomDelay()
    return (Data(), URLResponse())
  }

  private func randomDelay() async throws {
    try await Task.sleep(for: .seconds(Double.random(in: 0.1...3.0)))
  }
}
