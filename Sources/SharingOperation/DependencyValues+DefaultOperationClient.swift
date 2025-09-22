import Dependencies
import Operation

extension DependencyValues {
  /// The default `OperationClient` to use with ``SharedOperation``.
  public var defaultOperationClient: OperationClient {
    get { self[OperationClientKey.self] }
    set { self[OperationClientKey.self] = newValue }
  }

  private enum OperationClientKey: DependencyKey {
    static var liveValue: OperationClient {
      OperationClient()
    }

    static var testValue: OperationClient {
      OperationClient()
    }
  }
}
