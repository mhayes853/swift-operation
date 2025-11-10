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
    expectNoDifference(context.description, "[OperationContext.__Key_test = \(context.test)]")

    context.test2 = "Vlov"
    let expected = Set([
      "[OperationContext.__Key_test = \(context.test), OperationContext.__Key_test2 = Vlov]",
      "[OperationContext.__Key_test2 = Vlov, OperationContext.__Key_test = \(context.test)]"
    ])
    expectNoDifference(expected.contains(context.description), true)
  }
}

private let _defaultValue = 100

extension OperationContext {
  @ContextEntry fileprivate var test = _defaultValue
  @ContextEntry fileprivate var test2 = "Blob"
}
