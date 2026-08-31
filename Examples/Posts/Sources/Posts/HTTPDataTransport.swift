import Dependencies
import Foundation

// MARK: - HTTPDataTransport

package protocol HTTPDataTransport: Sendable {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataTransport {}

// MARK: - HTTPDataTransportKey

package enum HTTPDataTransportKey: DependencyKey {
  package static var liveValue: any HTTPDataTransport {
    URLSession.shared
  }
}
