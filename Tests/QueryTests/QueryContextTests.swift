import CustomDump
import Query
import Testing

@Suite("QueryContext tests")
struct QueryContextTests {
  @Test("Get Value For Key, Returns Default When No Value Set")
  func returnsDefaultValue() {
    let context = QueryContext()
    expectNoDifference(context.test, _defaultValue)
  }

  @Test("Get Value For Key, Returns Newly Set Value")
  func returnsNewlySetValue() {
    var context = QueryContext()
    context.test = _defaultValue + 100
    expectNoDifference(context.test, _defaultValue + 100)
  }

  @Test("Copy On Write")
  func copyOnWrite() {
    let context = QueryContext()
    var context2 = context
    context2.test = _defaultValue + 100
    expectNoDifference(context.test, _defaultValue)
    expectNoDifference(context2.test, _defaultValue + 100)
  }

  @Test("CustomStringConvertible")
  func customStringConvertible() {
    var context = QueryContext()
    expectNoDifference(context.description, "[]")

    context.test = _defaultValue + 200
    expectNoDifference(context.description, "[QueryContext.TestKey = \(context.test)]")

    context.test2 = "Vlov"
    let expected = Set([
      "[QueryContext.TestKey = \(context.test), QueryContext.TestKey2 = Vlov]",
      "[QueryContext.TestKey2 = Vlov, QueryContext.TestKey = \(context.test)]"
    ])
    expectNoDifference(expected.contains(context.description), true)
  }
}

private let _defaultValue = 100

extension QueryContext {
  fileprivate var test: Int {
    get { self[TestKey.self] }
    set { self[TestKey.self] = newValue }
  }

  private struct TestKey: Key {
    static var defaultValue: Int { _defaultValue }
  }

  fileprivate var test2: String {
    get { self[TestKey2.self] }
    set { self[TestKey2.self] = newValue }
  }

  private struct TestKey2: Key {
    static var defaultValue: String { "Blob" }
  }
}
