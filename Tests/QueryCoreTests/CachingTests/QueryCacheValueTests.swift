import CustomDump
import QueryCore
import Testing

@Suite("QueryCacheValue tests")
struct QueryCacheValueTests {
  @Test("Map Fresh")
  func mapFresh() {
    let value = QueryCacheValue.fresh("blob")
    expectNoDifference(value.map { $0.count }, .fresh(4))
  }

  @Test("Map Stale")
  func mapStale() {
    let value = QueryCacheValue.stale("blob")
    expectNoDifference(value.map { $0.count }, .stale(4))
  }

  @Test("Flat Map")
  func flatMap() {
    let value = QueryCacheValue.fresh("blob")
    expectNoDifference(value.flatMap { .stale($0.count) }, .stale(4))
  }
}
