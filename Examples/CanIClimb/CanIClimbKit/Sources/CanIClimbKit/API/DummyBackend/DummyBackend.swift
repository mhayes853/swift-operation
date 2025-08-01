import Foundation

public final class DummyBackend: CanIClimbAPI.DataTransport {
  public init() {}

  public func send(
    request: CanIClimbAPI.Request,
    in context: CanIClimbAPI.Request.Context
  ) async throws -> (Data, HTTPURLResponse) {
    try await self.randomDelay()
    return (
      Data(),
      HTTPURLResponse(
        url: context.baseURL,
        statusCode: 400,
        httpVersion: nil,
        headerFields: nil
      )!
    )
  }

  private func randomDelay() async throws {
    try await Task.sleep(for: .seconds(Double.random(in: 0.1...3.0)))
  }
}
