import CustomDump
import Query
import Testing

@Suite("QueryPath tests")
struct QueryPathTests {
  @Test(
    "Prefix Matches",
    arguments: [
      PrefixMatchesArgs(QueryPath(), QueryPath(), true),
      PrefixMatchesArgs(QueryPath([]), QueryPath(["foo"]), true),
      PrefixMatchesArgs(QueryPath([]), QueryPath("foo"), true),
      PrefixMatchesArgs(QueryPath(), QueryPath(["foo"]), true),
      PrefixMatchesArgs(QueryPath(["foo"]), QueryPath(["foo"]), true),
      PrefixMatchesArgs(QueryPath(["foo"]), QueryPath([]), false),
      PrefixMatchesArgs(QueryPath(["foo"]), QueryPath(["bar"]), false),
      PrefixMatchesArgs(QueryPath(["foo"]), QueryPath(["foo", "bar"]), true),
      PrefixMatchesArgs(QueryPath("foo"), QueryPath(["foo", "bar"]), true),
      PrefixMatchesArgs(QueryPath("foo"), QueryPath("bar"), false),
      PrefixMatchesArgs(QueryPath(["foo"]), QueryPath("foo"), true),
      PrefixMatchesArgs(QueryPath(["foo", "bar"]), QueryPath("foo"), false),
      PrefixMatchesArgs(QueryPath([1, 2, 3]), QueryPath([1, 2]), false),
      PrefixMatchesArgs(QueryPath([1, 2, 3]), QueryPath([1, 2, 3, 4]), true),
      PrefixMatchesArgs(QueryPath([1, true, "test"]), QueryPath(["test", 2]), false),
      PrefixMatchesArgs(QueryPath([1, "test"]), QueryPath([1, "test", 2]), true),
      PrefixMatchesArgs(QueryPath(), QueryPath(["foo", 1, 2, true, ["test"]]), true)
    ]
  )
  func prefixMatches(args: PrefixMatchesArgs) {
    expectNoDifference(args.a.isPrefix(of: args.b), args.doesMatch)
  }

  struct PrefixMatchesArgs: Hashable, Sendable {
    let a: QueryPath
    let b: QueryPath
    let doesMatch: Bool

    init(_ a: QueryPath, _ b: QueryPath, _ doesMatch: Bool) {
      self.a = a
      self.b = b
      self.doesMatch = doesMatch
    }
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
      EquatableArgs(QueryPath(), QueryPath(), true),
      EquatableArgs(QueryPath([]), QueryPath(["foo"]), false),
      EquatableArgs(QueryPath(), QueryPath(["foo"]), false),
      EquatableArgs(QueryPath(["foo"]), QueryPath([]), false),
      EquatableArgs(QueryPath(["foo"]), QueryPath(["bar"]), false),
      EquatableArgs(QueryPath(["foo", "bar"]), QueryPath(["foo", "bar"]), true),
      EquatableArgs(QueryPath("foo"), QueryPath(["foo"]), true),
      EquatableArgs(QueryPath("foo"), QueryPath(["bar"]), false),
      EquatableArgs(QueryPath(), QueryPath([]), true),
      EquatableArgs(QueryPath("foo"), QueryPath("bar"), false),
      EquatableArgs(QueryPath("foo"), QueryPath("foo"), true),
      EquatableArgs(QueryPath(["foo"]), QueryPath("foo"), true),
      EquatableArgs(QueryPath(["foo"]), QueryPath("bar"), false),
      EquatableArgs(QueryPath([1, 2, 3]), QueryPath([1, 2, 3]), true),
      EquatableArgs(QueryPath([1, 2, 3]), QueryPath([1, 2, 3, 4]), false),
      EquatableArgs(QueryPath([1, true, "test"]), QueryPath(["test", 2]), false),
      EquatableArgs(QueryPath([1, "test"]), QueryPath([1, "test", 2]), false),
      EquatableArgs(QueryPath(), QueryPath(["foo", 1, 2, true, ["test"]]), false)
    ]
  )
  func equatable(args: EquatableArgs) {
    expectNoDifference(args.a == args.b, args.doesMatch)
  }

  struct EquatableArgs: Hashable, Sendable {
    let a: QueryPath
    let b: QueryPath
    let doesMatch: Bool

    init(_ a: QueryPath, _ b: QueryPath, _ doesMatch: Bool) {
      self.a = a
      self.b = b
      self.doesMatch = doesMatch
    }
  }

  @Test(
    "Hashable",
    arguments: [
      HashableArgs(QueryPath(), QueryPath(), true),
      HashableArgs(QueryPath([]), QueryPath(["foo"]), false),
      HashableArgs(QueryPath(), QueryPath(["foo"]), false),
      HashableArgs(QueryPath(["foo"]), QueryPath([]), false),
      HashableArgs(QueryPath(["foo"]), QueryPath(["bar"]), false),
      HashableArgs(QueryPath(["foo", "bar"]), QueryPath(["foo", "bar"]), true),
      HashableArgs(QueryPath("foo"), QueryPath(["foo"]), true),
      HashableArgs(QueryPath("foo"), QueryPath(["bar"]), false),
      HashableArgs(QueryPath(), QueryPath([]), true),
      HashableArgs(QueryPath("foo"), QueryPath("bar"), false),
      HashableArgs(QueryPath("foo"), QueryPath("foo"), true),
      HashableArgs(QueryPath(["foo"]), QueryPath("foo"), true),
      HashableArgs(QueryPath(["foo"]), QueryPath("bar"), false),
      HashableArgs(QueryPath([1, 2, 3]), QueryPath([1, 2, 3]), true),
      HashableArgs(QueryPath([1, 2, 3]), QueryPath([1, 2, 3, 4]), false),
      HashableArgs(QueryPath([1, true, "test"]), QueryPath(["test", 2]), false),
      HashableArgs(QueryPath([1, "test"]), QueryPath([1, "test", 2]), false),
      HashableArgs(QueryPath(), QueryPath(["foo", 1, 2, true, ["test"]]), false)
    ]
  )
  func hashable(args: HashableArgs) {
    expectNoDifference(args.a.hashValue == args.b.hashValue, args.doesMatch)
  }

  struct HashableArgs: Hashable, Sendable {
    let a: QueryPath
    let b: QueryPath
    let doesMatch: Bool

    init(_ a: QueryPath, _ b: QueryPath, _ doesMatch: Bool) {
      self.a = a
      self.b = b
      self.doesMatch = doesMatch
    }
  }

  @Test(
    "Appending",
    arguments: [
      AppendingArgs(QueryPath(), QueryPath(), QueryPath()),
      AppendingArgs(QueryPath([]), QueryPath([]), QueryPath()),
      AppendingArgs(QueryPath([]), QueryPath("foo"), QueryPath("foo")),
      AppendingArgs(QueryPath("foo"), QueryPath([]), QueryPath("foo")),
      AppendingArgs(QueryPath(), QueryPath("foo"), QueryPath("foo")),
      AppendingArgs(QueryPath(), QueryPath(["foo", "bar"]), QueryPath(["foo", "bar"])),
      AppendingArgs(QueryPath("foo"), QueryPath(), QueryPath("foo")),
      AppendingArgs(QueryPath(["foo", "bar"]), QueryPath(), QueryPath(["foo", "bar"])),
      AppendingArgs(QueryPath("foo"), QueryPath("bar"), QueryPath(["foo", "bar"])),
      AppendingArgs(QueryPath(["foo", "bar"]), QueryPath(1), QueryPath(["foo", "bar", 1])),
      AppendingArgs(
        QueryPath(["foo", "bar"]),
        QueryPath([1, true]),
        QueryPath(["foo", "bar", 1, true])
      ),
      AppendingArgs(
        QueryPath("foo"),
        QueryPath(["bar", 1, true]),
        QueryPath(["foo", "bar", 1, true])
      )
    ]
  )
  func appending(_ args: AppendingArgs) {
    expectNoDifference(args.a.appending(args.b), args.expected)
  }

  struct AppendingArgs: Hashable, Sendable {
    let a: QueryPath
    let b: QueryPath
    let expected: QueryPath

    init(_ a: QueryPath, _ b: QueryPath, _ expected: QueryPath) {
      self.a = a
      self.b = b
      self.expected = expected
    }
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

  @Test(
    "Replace Subrange",
    arguments: [
      ReplaceSubrangeArgs(QueryPath("element"), 0..<1, ["foo"], QueryPath("foo")),
      ReplaceSubrangeArgs(
        QueryPath(["element", "bar"]),
        0..<1,
        ["foo"],
        QueryPath(["foo", "bar"])
      ),
      ReplaceSubrangeArgs(
        QueryPath(["element", "bar"]),
        1..<2,
        ["baz"],
        QueryPath(["element", "baz"])
      ),
      ReplaceSubrangeArgs(
        QueryPath(["element", "bar"]),
        0..<2,
        ["foo", "baz"],
        QueryPath(["foo", "baz"])
      ),
      ReplaceSubrangeArgs(
        QueryPath(["element", "bar", "baz"]),
        0..<1,
        QueryPath(),
        QueryPath(["bar", "baz"])
      ),
      ReplaceSubrangeArgs(QueryPath("element"), 0..<1, QueryPath(), QueryPath())
    ]
  )
  func replaceSubrange(args: ReplaceSubrangeArgs) {
    var path = args.path
    path.replaceSubrange(args.range, with: args.replacement)
    expectNoDifference(path, args.expected)
  }

  struct ReplaceSubrangeArgs: Hashable, Sendable {
    let path: QueryPath
    let range: Range<Int>
    let replacement: QueryPath
    let expected: QueryPath

    init(_ path: QueryPath, _ range: Range<Int>, _ replacement: QueryPath, _ expected: QueryPath) {
      self.path = path
      self.range = range
      self.replacement = replacement
      self.expected = expected
    }
  }

  #if swift(>=6.2) && os(macOS) || os(Linux) || os(Windows)
    // NB: Parameterized tests don't support exit testing due to the macro expanding an
    // @convention(c) closure. So inline all of this instead.

    @Test("Index Out of Range (Reading)")
    func indexOutOfRangeReading() async {
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath()[0]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath()[1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath()[-1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath()[2983]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath()[-198]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath([])[0]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath([])[1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath([])[-1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath([])[2983]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath([])[18]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath("element")[1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath("element")[1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath("element")[100]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath("element")[13]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath(["element", "bar"])[-1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath(["element", "bar"])[2]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = QueryPath(["element"])[1]
      }
    }

    @Test("Index Out of Range (Writing)")
    func indexOutOfRangeWriting() async {
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath()
        p[0] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath()
        p[1] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath()
        p[-1] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath()
        p[2983] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath()
        p[2983] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath()
        p[-198] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath([])
        p[0] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath([])
        p[1] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath([])
        p[-1] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath([])
        p[2983] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath([])
        p[18] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath([])
        p[18] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath("element")
        p[1] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath("element")
        p[1] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath("element")
        p[100] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath("element")
        p[13] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath("element")
        p[13] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath(["element", "bar"])
        p[-1] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath(["element", "bar"])
        p[2] = 0
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = QueryPath(["element"])
        p[1] = 0
      }
    }

    @Test("Exits When Replacing Invalid Subrange")
    func exitsWhenReplacingInvalidSubrange() async {
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var path = QueryPath()
        path.replaceSubrange(0..<1, with: [])
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var path = QueryPath("blob")
        path.replaceSubrange(0..<2, with: [])
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var path = QueryPath(["blob", "foo"])
        path.replaceSubrange(0..<3, with: [])
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var path = QueryPath(["blob", "foo"])
        path.replaceSubrange(-1..<3, with: [])
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var path = QueryPath(["blob", "foo"])
        path.replaceSubrange(-1..<1, with: [])
      }
    }
  #endif
}

private struct SomeValue: Hashable, Sendable {
}

extension Comment {
  fileprivate static let indexOutOfRange = Self(rawValue: QueryPath._indexOutOfRangeMessage)
}
