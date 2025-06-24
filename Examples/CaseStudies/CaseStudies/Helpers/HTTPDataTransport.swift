import Foundation

// MARK: - HTTPDataTransport

protocol HTTPDataTransport: Sendable {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - URLSession

extension URLSession: HTTPDataTransport {}
