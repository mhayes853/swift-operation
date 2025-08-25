import CustomDump
import Operation
import Testing

@Suite("OperationContext tests")
struct OperationContextTests {
  @Test("Get Value For Key, Returns Default When No Value Set")
  func returnsDefaultValue() {
    let context = OperationContext()
    expectNoDifference(context.test, _defaultValue)
  }

  @Test("Get Value For Key, Returns Newly Set Value")
  func returnsNewlySetValue() {
    var context = OperationContext()
    context.test = _defaultValue + 100
    expectNoDifference(context.test, _defaultValue + 100)
  }

  @Test("Copy On Write")
  func copyOnWrite() {
    let context = OperationContext()
    var context2 = context
    context2.test = _defaultValue + 100
    expectNoDifference(context.test, _defaultValue)
    expectNoDifference(context2.test, _defaultValue + 100)
  }

  @Test("CustomStringConvertible")
  func customStringConvertible() {
    var context = OperationContext()
    expectNoDifference(context.description, "[]")

    context.test = _defaultValue + 200
    expectNoDifference(context.description, "[OperationContext.TestKey = \(context.test)]")

    context.test2 = "Vlov"
    let expected = Set([
      "[OperationContext.TestKey = \(context.test), OperationContext.TestKey2 = Vlov]",
      "[OperationContext.TestKey2 = Vlov, OperationContext.TestKey = \(context.test)]"
    ])
    expectNoDifference(expected.contains(context.description), true)
  }
}

private let _defaultValue = 100

extension OperationContext {
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
