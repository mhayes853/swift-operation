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
      (QueryPath([]), QueryPath("foo"), true),
      (QueryPath(), QueryPath(["foo"]), true),
      (QueryPath(["foo"]), QueryPath(["foo"]), true),
      (QueryPath(["foo"]), QueryPath([]), false),
      (QueryPath(["foo"]), QueryPath(["bar"]), false),
      (QueryPath(["foo"]), QueryPath(["foo", "bar"]), true),
      (QueryPath("foo"), QueryPath(["foo", "bar"]), true),
      (QueryPath("foo"), QueryPath("bar"), false),
      (QueryPath(["foo"]), QueryPath("foo"), true),
      (QueryPath(["foo", "bar"]), QueryPath("foo"), false),
      (QueryPath([1, 2, 3]), QueryPath([1, 2]), false),
      (QueryPath([1, 2, 3]), QueryPath([1, 2, 3, 4]), true),
      (QueryPath([1, true, "test"]), QueryPath(["test", 2]), false),
      (QueryPath([1, "test"]), QueryPath([1, "test", 2]), true),
      (QueryPath(), QueryPath(["foo", 1, 2, true, ["test"]]), true)
    ]
  )
  func prefixMatches(a: QueryPath, b: QueryPath, doesMatch: Bool) {
    expectNoDifference(a.isPrefix(of: b), doesMatch)
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
        QueryPath([1, NetworkConnectionStatus.disconnected]),
        "QueryPath([1, disconnected])"
      )
    ]
  )
  func customStringConvertible(path: QueryPath, string: String) {
    expectNoDifference(path.description, string)
  }

  @Test(
    "Equatable",
    arguments: [
      (QueryPath(), QueryPath(), true),
      (QueryPath([]), QueryPath(["foo"]), false),
      (QueryPath(), QueryPath(["foo"]), false),
      (QueryPath(["foo"]), QueryPath([]), false),
      (QueryPath(["foo"]), QueryPath(["bar"]), false),
      (QueryPath(["foo", "bar"]), QueryPath(["foo", "bar"]), true),
      (QueryPath("foo"), QueryPath(["foo"]), true),
      (QueryPath("foo"), QueryPath(["bar"]), false),
      (QueryPath(), QueryPath([]), true),
      (QueryPath("foo"), QueryPath("bar"), false),
      (QueryPath("foo"), QueryPath("foo"), true),
      (QueryPath(["foo"]), QueryPath("foo"), true),
      (QueryPath(["foo"]), QueryPath("bar"), false),
      (QueryPath([1, 2, 3]), QueryPath([1, 2, 3]), true),
      (QueryPath([1, 2, 3]), QueryPath([1, 2, 3, 4]), false),
      (QueryPath([1, true, "test"]), QueryPath(["test", 2]), false),
      (QueryPath([1, "test"]), QueryPath([1, "test", 2]), false),
      (QueryPath(), QueryPath(["foo", 1, 2, true, ["test"]]), false)
    ]
  )
  func equatable(a: QueryPath, b: QueryPath, doesMatch: Bool) {
    expectNoDifference(a == b, doesMatch)
  }

  @Test(
    "Hashable",
    arguments: [
      (QueryPath(), QueryPath(), true),
      (QueryPath([]), QueryPath(["foo"]), false),
      (QueryPath(), QueryPath(["foo"]), false),
      (QueryPath(["foo"]), QueryPath([]), false),
      (QueryPath(["foo"]), QueryPath(["bar"]), false),
      (QueryPath(["foo", "bar"]), QueryPath(["foo", "bar"]), true),
      (QueryPath("foo"), QueryPath(["foo"]), true),
      (QueryPath("foo"), QueryPath(["bar"]), false),
      (QueryPath(), QueryPath([]), true),
      (QueryPath("foo"), QueryPath("bar"), false),
      (QueryPath("foo"), QueryPath("foo"), true),
      (QueryPath(["foo"]), QueryPath("foo"), true),
      (QueryPath(["foo"]), QueryPath("bar"), false),
      (QueryPath([1, 2, 3]), QueryPath([1, 2, 3]), true),
      (QueryPath([1, 2, 3]), QueryPath([1, 2, 3, 4]), false),
      (QueryPath([1, true, "test"]), QueryPath(["test", 2]), false),
      (QueryPath([1, "test"]), QueryPath([1, "test", 2]), false),
      (QueryPath(), QueryPath(["foo", 1, 2, true, ["test"]]), false)
    ]
  )
  func hashable(a: QueryPath, b: QueryPath, doesMatch: Bool) {
    expectNoDifference(a.hashValue == b.hashValue, doesMatch)
  }

  @Test(
    "Appending",
    arguments: [
      (QueryPath(), QueryPath(), QueryPath()),
      (QueryPath([]), QueryPath([]), QueryPath()),
      (QueryPath([]), QueryPath("foo"), QueryPath("foo")),
      (QueryPath("foo"), QueryPath([]), QueryPath("foo")),
      (QueryPath(), QueryPath("foo"), QueryPath("foo")),
      (QueryPath(), QueryPath(["foo", "bar"]), QueryPath(["foo", "bar"])),
      (QueryPath("foo"), QueryPath(), QueryPath("foo")),
      (QueryPath(["foo", "bar"]), QueryPath(), QueryPath(["foo", "bar"])),
      (QueryPath("foo"), QueryPath("bar"), QueryPath(["foo", "bar"])),
      (QueryPath(["foo", "bar"]), QueryPath(1), QueryPath(["foo", "bar", 1])),
      (QueryPath(["foo", "bar"]), QueryPath([1, true]), QueryPath(["foo", "bar", 1, true])),
      (QueryPath("foo"), QueryPath(["bar", 1, true]), QueryPath(["foo", "bar", 1, true]))
    ]
  )
  func appending(p1: QueryPath, p2: QueryPath, expected: QueryPath) {
    expectNoDifference(p1.appending(p2), expected)
  }

  @Test(
    "End Index",
    arguments: [
      (QueryPath(), 0),
      (QueryPath([]), 0),
      (QueryPath("foo"), 1),
      (QueryPath(["foo"]), 1),
      (QueryPath(["foo", "bar"]), 2),
      (QueryPath(["foo", "bar", 1]), 3)
    ]
  )
  func endIndex(path: QueryPath, index: Int) {
    expectNoDifference(path.endIndex, index)
  }

  #if swift(>=6.2) && os(macOS) || os(Linux) || os(Windows)
    // NB: Parameterized tests don't support exit testing due to the macro expanding an
    // @convention(c) closure. So inline all of this instead.

    @Test("Index Out of Range (Reading)")
    func indexOutOfRangeReading() async {
      let comment = Comment(rawValue: QueryPath._indexOutOfRangeMessage)
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath()[0]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath()[1]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath()[-1]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath()[2983]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath()[-198]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath([])[0]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath([])[1]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath([])[-1]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath([])[2983]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath([])[18]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath("element")[1]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath("element")[1]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath("element")[100]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath("element")[13]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath(["element", "bar"])[-1]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath(["element", "bar"])[2]
      }
      await #expect(processExitsWith: .failure, comment) {
        _ = QueryPath(["element"])[1]
      }
    }

    @Test("Index Out of Range (Writing)")
    func indexOutOfRangeWriting() async {
      let comment = Comment(rawValue: QueryPath._indexOutOfRangeMessage)
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath()
        p[0] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath()
        p[1] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath()
        p[-1] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath()
        p[2983] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath()
        p[2983] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath()
        p[-198] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath([])
        p[0] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath([])
        p[1] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath([])
        p[-1] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath([])
        p[2983] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath([])
        p[18] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath("element")
        p[1] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath("element")
        p[1] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath("element")
        p[100] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath("element")
        p[13] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath(["element", "bar"])
        p[-1] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath(["element", "bar"])
        p[2] = 0
      }
      await #expect(processExitsWith: .failure, comment) {
        var p = QueryPath(["element"])
        p[1] = 0
      }
    }
  #endif

  @Test(
    "Subscripting",
    arguments: [
      (QueryPath("bar"), 0, AnyHashableSendable("bar")),
      (QueryPath(["bar"]), 0, AnyHashableSendable("bar")),
      (QueryPath(["bar", "baz"]), 1, AnyHashableSendable("baz"))
    ]
  )
  func subscripting(path: QueryPath, index: Int, readValue: AnyHashableSendable) {
    var path = path
    expectNoDifference(AnyHashableSendable(path[index]), readValue)

    path[index] = 0
    expectNoDifference(AnyHashableSendable(path[index]), 0)
  }
}

private struct SomeValue: Hashable, Sendable {
}
