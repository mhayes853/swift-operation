import Dependencies
import Foundation

// MARK: - HTTPDataTransport

protocol HTTPDataTransport: Sendable {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataTransport {}

// MARK: - HTTPDataTransportKey

enum HTTPDataTransportKey: DependencyKey {
  static var liveValue: any HTTPDataTransport {
    URLSession.shared
  }
}
