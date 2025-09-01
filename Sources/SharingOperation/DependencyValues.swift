import Dependencies
import Foundation
import IssueReporting
@_spi(Warnings) import Operation

// MARK: - OperationClient

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

// MARK: - NetworkObserver

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
              $0.networkObserver = MyPlatformObserver()
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

// MARK: - DateDependencyClock

/// A `OperationClock` that uses `@Depenendency(\.date)` to compute the current date.
public struct DateDependencyClock: OperationClock {
  @Dependency(\.date) private var date

  public func now() -> Date {
    self.date.now
  }
}

extension OperationClock where Self == DateDependencyClock {
  /// A `OperationClock` that uses `@Depenendency(\.date)` to compute the current date.
  public static var dateDependency: Self {
    DateDependencyClock()
  }
}
