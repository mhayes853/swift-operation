import CanIClimbKit
import DependenciesTestSupport
import SharingQuery
import Testing

@Suite(
  .dependencies {
    $0.defaultQueryClient = QueryClient()
    $0.defaultDatabase = try! canIClimbDatabase()
  }
)
struct DependenciesTestSuite {}
