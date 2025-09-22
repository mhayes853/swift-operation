import Dependencies
@_spi(Warnings) import Operation

// MARK: - DependencyValues

extension DependencyValues {
  /// The default `NetworkObserver` to use with ``Sharing/SharedReaderKey/networkStatus``.
  public var defaultNetworkObserver: any NetworkObserver & Sendable {
    get { self[NetworkObserverKey.self] }
    set { self[NetworkObserverKey.self] = newValue }
  }

  private enum NetworkObserverKey: DependencyKey {
    static var liveValue: any NetworkObserver & Sendable {
      if let observer = OperationClient.defaultNetworkObserver {
        return observer
      }
      if Self.shouldReportUnimplemented {
        reportWarning(.noDefaultNetworkObserver)
      }
      return MockNetworkObserver()
    }
  }
}

// MARK: - Warning

extension OperationWarning {
  public static var noDefaultNetworkObserver: Self {
    """
    Your current platform does not have a default NetworkObserver, a MockNetworkObserver instance \
    will be used instead.

    If you wish to support network observing in your application, you can use the \
    `prepareDependencies` tool as early as possible in your application's lifecycle to use a \
    custom NetworkObserver instance.

        @main
        struct MyApp {
          static func main() {
            prepareDependencies {
              $0.defaultNetworkObserver = MyPlatformObserver()
            }
          }

          // ...
        }

        struct MyPlatformObserver: NetworkObserver {
          // ...
        }
    """
  }
}
