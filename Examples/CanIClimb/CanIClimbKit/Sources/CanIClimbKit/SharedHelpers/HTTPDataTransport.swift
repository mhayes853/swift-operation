import Foundation
import Synchronization

// MARK: - HTTPDataTransport

public protocol HTTPDataTransport: Sendable {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - URLSession Conformance

extension URLSession: HTTPDataTransport {}

// MARK: - MockHTTPDataTransport

public final class MockHTTPDataTransport: Sendable {
  public let handler: Mutex<@Sendable (URLRequest) async throws -> (StatusCode, ResponseBody)?>

  public init(
    handler: @escaping @Sendable (URLRequest) async throws -> (StatusCode, ResponseBody)?
  ) {
    self.handler = Mutex(handler)
  }
}

extension HTTPDataTransport where Self == MockHTTPDataTransport {
  public static func mock(
    handler: @escaping @Sendable (
      URLRequest
    ) async throws -> (MockHTTPDataTransport.StatusCode, MockHTTPDataTransport.ResponseBody)?
  ) -> Self {
    MockHTTPDataTransport(handler: handler)
  }

  public static var never: Self {
    .mock { _ in try await Task.never() }
  }

  public static var throwing: Self {
    .mock { _ in throw SomeError() }
  }
}

private struct SomeError: Error {}

extension MockHTTPDataTransport: HTTPDataTransport {
  public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    let handler = self.handler.withLock { $0 }
    guard let (status, body) = try await handler(request) else {
      throw SomeError()
    }
    let data = try body.data()
    return (
      data,
      HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    )
  }
}

extension MockHTTPDataTransport {
  public typealias StatusCode = Int
}

extension MockHTTPDataTransport {
  public enum ResponseBody: Sendable {
    case data(Data)
    case json(any Encodable & Sendable, JSONEncoder)
  }
}

extension MockHTTPDataTransport.ResponseBody {
  public static func json(_ encodable: any Encodable & Sendable) -> Self {
    .json(encodable, JSONEncoder())
  }
}

extension MockHTTPDataTransport.ResponseBody {
  public static let empty = Self.data(Data())
}

extension MockHTTPDataTransport.ResponseBody {
  public func data() throws -> Data {
    switch self {
    case .data(let data): data
    case .json(let encodable, let encoder): try encoder.encode(encodable)
    }
  }
}
