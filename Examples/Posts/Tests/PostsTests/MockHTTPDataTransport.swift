import Foundation

@testable import Posts

struct MockHTTPDataTransport: HTTPDataTransport {
  let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await self.handler(request)
  }
}

func response(
  for request: URLRequest,
  statusCode: Int = 200,
  data: Data
) -> (Data, URLResponse) {
  (
    data,
    HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )!
  )
}
