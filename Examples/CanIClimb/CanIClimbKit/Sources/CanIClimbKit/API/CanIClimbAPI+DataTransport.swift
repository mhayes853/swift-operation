import Foundation

// MARK: - Transport

extension CanIClimbAPI {
  public protocol DataTransport: Sendable {
    func send(
      request: Request,
      in context: Request.Context
    ) async throws -> (Data, HTTPURLResponse)
  }
}

// MARK: - HTTPDataTransport

extension HTTPDataTransport where Self: CanIClimbAPI.DataTransport {
  public func send(
    request: CanIClimbAPI.Request,
    in context: CanIClimbAPI.Request.Context
  ) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await self.data(for: request.urlRequest(in: context))
    guard let response = response as? HTTPURLResponse else { throw NonHTTPResponseError() }
    return (data, response)
  }
}

private struct NonHTTPResponseError: Error {}

extension URLSession: CanIClimbAPI.DataTransport {}
extension MockHTTPDataTransport: CanIClimbAPI.DataTransport {}
