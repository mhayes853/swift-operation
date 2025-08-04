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

// MARK: - Mock Transport

extension CanIClimbAPI {
  public struct MockDataTransport: DataTransport {
    private let _send:
      @Sendable (
        Request,
        Request.Context
      ) async throws -> (MockHTTPDataTransport.StatusCode, MockHTTPDataTransport.ResponseBody)

    public init(
      send: @escaping @Sendable (
        CanIClimbAPI.Request,
        CanIClimbAPI.Request.Context
      ) async throws -> (MockHTTPDataTransport.StatusCode, MockHTTPDataTransport.ResponseBody)
    ) {
      self._send = send
    }

    public func send(
      request: Request,
      in context: Request.Context
    ) async throws -> (Data, HTTPURLResponse) {
      let (status, body) = try await self._send(request, context)
      return try (
        body.data(),
        HTTPURLResponse(
          url: request.urlRequest(in: context).url!,
          statusCode: status,
          httpVersion: nil,
          headerFields: nil
        )!
      )
    }
  }
}

extension CanIClimbAPI.DataTransport where Self == CanIClimbAPI.MockDataTransport {
  public static func mock(
    send: @escaping @Sendable (
      CanIClimbAPI.Request,
      CanIClimbAPI.Request.Context
    ) async throws -> (MockHTTPDataTransport.StatusCode, MockHTTPDataTransport.ResponseBody)
  ) -> Self {
    CanIClimbAPI.MockDataTransport(send: send)
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
