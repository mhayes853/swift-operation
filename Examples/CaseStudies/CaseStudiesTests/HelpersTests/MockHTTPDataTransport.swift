import ConcurrencyExtras
import Foundation
import Synchronization

@testable import CaseStudies

// MARK: - MockHTTPDataTransport

final class MockHTTPDataTransport: Sendable {
  let handler: Mutex<@Sendable (URLRequest) async throws -> (StatusCode, ResponseBody)>

  init(handler: @escaping @Sendable (URLRequest) async throws -> (StatusCode, ResponseBody)) {
    self.handler = Mutex(handler)
  }
}

extension HTTPDataTransport where Self == MockHTTPDataTransport {
  static func mock(
    handler: @escaping @Sendable (
      URLRequest
    ) async throws -> (MockHTTPDataTransport.StatusCode, MockHTTPDataTransport.ResponseBody)
  ) -> Self {
    MockHTTPDataTransport(handler: handler)
  }

  static var never: Self {
    .mock { _ in try await Task.never() }
  }

  static var throwing: Self {
    .mock { _ in throw SomeError() }
  }
}

private struct SomeError: Error {}

// MARK: - HTTPDataTransport Conformance

extension MockHTTPDataTransport: HTTPDataTransport {
  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    let handler = self.handler.withLock { $0 }
    let (status, body) = try await handler(request)
    let data = try body.data()
    return (
      data,
      HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    )
  }
}

// MARK: - StatusCode

extension MockHTTPDataTransport {
  typealias StatusCode = Int
}

// MARK: - ResponseBody

extension MockHTTPDataTransport {
  enum ResponseBody: Sendable {
    case data(Data)
    case json(any Encodable & Sendable, JSONEncoder)
  }
}

extension MockHTTPDataTransport.ResponseBody {
  static func json(_ encodable: any Encodable & Sendable) -> Self {
    .json(encodable, JSONEncoder())
  }
}

extension MockHTTPDataTransport.ResponseBody {
  static let empty = Self.data(Data())
}

extension MockHTTPDataTransport.ResponseBody {
  fileprivate func data() throws -> Data {
    switch self {
    case let .data(data): data
    case let .json(encodable, encoder): try encoder.encode(encodable)
    }
  }
}
