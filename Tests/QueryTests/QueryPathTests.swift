import CustomDump
import Query
import Testing

@Suite("QueryPath tests")
struct QueryPathTests {
  @Test(
    "Prefix Matches",
    arguments: [
      (QueryPath(), QueryPath(), true),
      (QueryPath([]), QueryPath(["foo"]), true),
      (QueryPath(), QueryPath(["foo"]), true),
      (QueryPath(["foo"]), QueryPath([]), false),
      (QueryPath(["foo"]), QueryPath(["bar"]), false),
      (QueryPath(["foo"]), QueryPath(["foo", "bar"]), true),
      (QueryPath([1, 2, 3]), QueryPath([1, 2]), false),
      (QueryPath([1, 2, 3]), QueryPath([1, 2, 3, 4]), true),
      (QueryPath([1, true, "test"]), QueryPath(["test", 2]), false),
      (QueryPath([1, "test"]), QueryPath([1, "test", 2]), true),
      (QueryPath(), QueryPath(["foo", 1, 2, true, ["test"]]), true)
    ]
  )
  func prefixMatches(a: QueryPath, b: QueryPath, doesMatch: Bool) {
    expectNoDifference(a.prefixMatches(other: b), doesMatch)
  }

  @Test(
    "CustomStringConvertible",
    arguments: [
      (QueryPath(), #"QueryPath([])"#),
      (QueryPath([1, "hello", true]), #"QueryPath([1, "hello", true])"#),
      (QueryPath([1, Substring("hello"), true]), #"QueryPath([1, "hello", true])"#),
      (
        QueryPath([1, ["hello", "blob"]]),
        #"QueryPath([1, ["hello", "blob"]])"#
      ),
      (
        QueryPath([1, SomeValue()]),
        "QueryPath([1, SomeValue()])"
      ),
      (
        QueryPath([1, NetworkStatus.disconnected]),
        "QueryPath([1, disconnected])"
      )
    ]
  )
  func customStringConvertible(path: QueryPath, string: String) {
    expectNoDifference(path.description, string)
  }
}

private struct SomeValue: Hashable, Sendable {
}
