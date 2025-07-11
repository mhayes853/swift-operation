import CanIClimbKit
import DependenciesTestSupport
import SharingQuery
import Testing

@Suite(
  .dependencies {
    $0.defaultQueryClient = QueryClient()
    $0.defaultDatabase = try! canIClimbDatabase()
    $0.defaultNetworkObserver = MockNetworkObserver()
    $0[CurrentUser.self] = CurrentUser(database: $0.defaultDatabase)
  }
)
struct DependenciesTestSuite {}
