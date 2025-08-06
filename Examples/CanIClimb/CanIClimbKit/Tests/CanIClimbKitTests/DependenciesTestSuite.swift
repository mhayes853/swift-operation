import CanIClimbKit
import DependenciesTestSupport
import SharingQuery
import Testing

@Suite(
  .dependencies {
    $0.defaultQueryClient = QueryClient()
    $0.defaultDatabase = try! canIClimbDatabase()
    $0.defaultNetworkObserver = MockNetworkObserver()
    $0[ScheduleableAlarm.SyncEngine.self] = ScheduleableAlarm.SyncEngine(
      database: $0.defaultDatabase,
      store: ScheduleableAlarm.NoopStore()
    )
  }
)
struct DependenciesTestSuite {}
