import Dependencies
import Foundation
import IssueReporting
@_spi(Warnings) import Query

// MARK: - QueryClient

extension DependencyValues {
  public var defaultQueryClient: QueryClient {
    get { self[QueryClientKey.self] }
    set { self[QueryClientKey.self] = newValue }
  }

  private enum QueryClientKey: DependencyKey {
    static var liveValue: QueryClient {
      QueryClient()
    }

    static var testValue: QueryClient {
      QueryClient()
    }
  }
}

// MARK: - NetworkObserver

extension DependencyValues {
  public var defaultNetworkObserver: NetworkObserver {
    get { self[NetworkObserverKey.self] }
    set { self[NetworkObserverKey.self] = newValue }
  }

  private enum NetworkObserverKey: DependencyKey {
    static var liveValue: NetworkObserver {
      #if canImport(Network)
        NWPathMonitorObserver.shared
      #elseif browser && canImport(JavaScriptKit)
        NavigatorObserver.shared
      #else
        reportWarning(.noDefaultNetworkObserver)
        return MockNetworkObserver()
      #endif
    }
  }
}

extension QueryWarning {
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

public struct DateDependencyClock: QueryClock {
  @Dependency(\.date) private var date

  public func now() -> Date {
    self.date.now
  }
}

extension QueryClock where Self == DateDependencyClock {
  public static var dateDependency: Self {
    DateDependencyClock()
  }
}
