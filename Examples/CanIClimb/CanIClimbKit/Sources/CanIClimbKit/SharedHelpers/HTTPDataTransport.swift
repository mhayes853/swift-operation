import Foundation

// MARK: - HTTPDataTransport

public protocol HTTPDataTransport: Sendable {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public struct HTTPDataResponse: Sendable {
  public typealias StatusCode = Int

  public var statusCode: StatusCode
  public var body: Body
  public var headerFields: [String: String]

  public init(
    statusCode: StatusCode,
    body: Body = .empty,
    headerFields: [String: String] = [String: String]()
  ) {
    self.statusCode = statusCode
    self.body = body
    self.headerFields = headerFields
  }

  public static func json(
    _ value: some Encodable & Sendable,
    statusCode: StatusCode = 200,
    encoder: JSONEncoder = JSONEncoder()
  ) -> Self {
    Self(statusCode: statusCode, body: .json(value, encoder))
  }

  func result(for request: URLRequest) throws -> (Data, URLResponse) {
    guard let url = request.url else { throw MissingURLError() }
    return (
      try self.body.data(),
      HTTPURLResponse(
        url: url,
        statusCode: self.statusCode,
        httpVersion: nil,
        headerFields: self.headerFields
      )!
    )
  }

  public enum Body: Sendable {
    case data(Data)
    case json(any Encodable & Sendable, JSONEncoder)

    public static let empty = Self.data(Data())

    public static func json(_ encodable: any Encodable & Sendable) -> Self {
      .json(encodable, JSONEncoder())
    }

    public func data() throws -> Data {
      switch self {
      case .data(let data): data
      case .json(let encodable, let encoder): try encoder.encode(encodable)
      }
    }
  }
}

private struct MissingURLError: Error {}

// MARK: - URLSession Conformance

extension URLSession: HTTPDataTransport {}

// MARK: - MockHTTPDataTransport

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
    .mock { _ in nil }
  }
}

public struct MockHTTPDataTransport: HTTPDataTransport {
  public typealias StatusCode = HTTPDataResponse.StatusCode
  public typealias ResponseBody = HTTPDataResponse.Body

  private let handler: @Sendable (URLRequest) async throws -> (StatusCode, ResponseBody)?

  public init(
    handler: @escaping @Sendable (URLRequest) async throws -> (StatusCode, ResponseBody)?
  ) {
    self.handler = handler
  }

  public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    guard let (status, body) = try await self.handler(request) else {
      throw SomeError()
    }
    return try HTTPDataResponse(statusCode: status, body: body).result(for: request)
  }

  private struct SomeError: Error {}
}
