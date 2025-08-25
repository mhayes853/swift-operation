import CustomDump
import Operation
import Testing

@Suite("OperationPath tests")
struct OperationPathTests {
  @Test(
    "Prefix Matches",
    arguments: [
      PrefixMatchesArgs(OperationPath(), OperationPath(), true),
      PrefixMatchesArgs(OperationPath([]), OperationPath(["foo"]), true),
      PrefixMatchesArgs(OperationPath([]), OperationPath("foo"), true),
      PrefixMatchesArgs(OperationPath(), OperationPath(["foo"]), true),
      PrefixMatchesArgs(OperationPath(["foo"]), OperationPath(["foo"]), true),
      PrefixMatchesArgs(OperationPath(["foo"]), OperationPath([]), false),
      PrefixMatchesArgs(OperationPath(["foo"]), OperationPath(["bar"]), false),
      PrefixMatchesArgs(OperationPath(["foo"]), OperationPath(["foo", "bar"]), true),
      PrefixMatchesArgs(OperationPath("foo"), OperationPath(["foo", "bar"]), true),
      PrefixMatchesArgs(OperationPath("foo"), OperationPath("bar"), false),
      PrefixMatchesArgs(OperationPath(["foo"]), OperationPath("foo"), true),
      PrefixMatchesArgs(OperationPath(["foo", "bar"]), OperationPath("foo"), false),
      PrefixMatchesArgs(OperationPath([1, 2, 3]), OperationPath([1, 2]), false),
      PrefixMatchesArgs(OperationPath([1, 2, 3]), OperationPath([1, 2, 3, 4]), true),
      PrefixMatchesArgs(OperationPath([1, true, "test"]), OperationPath(["test", 2]), false),
      PrefixMatchesArgs(OperationPath([1, "test"]), OperationPath([1, "test", 2]), true),
      PrefixMatchesArgs(OperationPath(), OperationPath(["foo", 1, 2, true, ["test"]]), true)
    ]
  )
  func prefixMatches(args: PrefixMatchesArgs) {
    expectNoDifference(args.a.isPrefix(of: args.b), args.doesMatch)
  }

  struct PrefixMatchesArgs: Hashable, Sendable {
    let a: OperationPath
    let b: OperationPath
    let doesMatch: Bool

    init(_ a: OperationPath, _ b: OperationPath, _ doesMatch: Bool) {
      self.a = a
      self.b = b
      self.doesMatch = doesMatch
    }
  }

  @Test(
    "CustomStringConvertible",
    arguments: [
      (OperationPath(), #"OperationPath([])"#),
      (OperationPath([1, "hello", true]), #"OperationPath([1, "hello", true])"#),
      (OperationPath([1, Substring("hello"), true]), #"OperationPath([1, "hello", true])"#),
      (
        OperationPath([1, ["hello", "blob"]]),
        #"OperationPath([1, ["hello", "blob"]])"#
      ),
      (
        OperationPath([1, SomeValue()]),
        "OperationPath([1, SomeValue()])"
      ),
      (
        OperationPath([1, NetworkConnectionStatus.disconnected]),
        "OperationPath([1, disconnected])"
      )
    ]
  )
  func customStringConvertible(path: OperationPath, string: String) {
    expectNoDifference(path.description, string)
  }

  @Test(
    "Equatable",
    arguments: [
      EquatableArgs(OperationPath(), OperationPath(), true),
      EquatableArgs(OperationPath([]), OperationPath(["foo"]), false),
      EquatableArgs(OperationPath(), OperationPath(["foo"]), false),
      EquatableArgs(OperationPath(["foo"]), OperationPath([]), false),
      EquatableArgs(OperationPath(["foo"]), OperationPath(["bar"]), false),
      EquatableArgs(OperationPath(["foo", "bar"]), OperationPath(["foo", "bar"]), true),
      EquatableArgs(OperationPath("foo"), OperationPath(["foo"]), true),
      EquatableArgs(OperationPath("foo"), OperationPath(["bar"]), false),
      EquatableArgs(OperationPath(), OperationPath([]), true),
      EquatableArgs(OperationPath("foo"), OperationPath("bar"), false),
      EquatableArgs(OperationPath("foo"), OperationPath("foo"), true),
      EquatableArgs(OperationPath(["foo"]), OperationPath("foo"), true),
      EquatableArgs(OperationPath(["foo"]), OperationPath("bar"), false),
      EquatableArgs(OperationPath([1, 2, 3]), OperationPath([1, 2, 3]), true),
      EquatableArgs(OperationPath([1, 2, 3]), OperationPath([1, 2, 3, 4]), false),
      EquatableArgs(OperationPath([1, true, "test"]), OperationPath(["test", 2]), false),
      EquatableArgs(OperationPath([1, "test"]), OperationPath([1, "test", 2]), false),
      EquatableArgs(OperationPath(), OperationPath(["foo", 1, 2, true, ["test"]]), false)
    ]
  )
  func equatable(args: EquatableArgs) {
    expectNoDifference(args.a == args.b, args.doesMatch)
  }

  struct EquatableArgs: Hashable, Sendable {
    let a: OperationPath
    let b: OperationPath
    let doesMatch: Bool

    init(_ a: OperationPath, _ b: OperationPath, _ doesMatch: Bool) {
      self.a = a
      self.b = b
      self.doesMatch = doesMatch
    }
  }

  @Test(
    "Hashable",
    arguments: [
      HashableArgs(OperationPath(), OperationPath(), true),
      HashableArgs(OperationPath([]), OperationPath(["foo"]), false),
      HashableArgs(OperationPath(), OperationPath(["foo"]), false),
      HashableArgs(OperationPath(["foo"]), OperationPath([]), false),
      HashableArgs(OperationPath(["foo"]), OperationPath(["bar"]), false),
      HashableArgs(OperationPath(["foo", "bar"]), OperationPath(["foo", "bar"]), true),
      HashableArgs(OperationPath("foo"), OperationPath(["foo"]), true),
      HashableArgs(OperationPath("foo"), OperationPath(["bar"]), false),
      HashableArgs(OperationPath(), OperationPath([]), true),
      HashableArgs(OperationPath("foo"), OperationPath("bar"), false),
      HashableArgs(OperationPath("foo"), OperationPath("foo"), true),
      HashableArgs(OperationPath(["foo"]), OperationPath("foo"), true),
      HashableArgs(OperationPath(["foo"]), OperationPath("bar"), false),
      HashableArgs(OperationPath([1, 2, 3]), OperationPath([1, 2, 3]), true),
      HashableArgs(OperationPath([1, 2, 3]), OperationPath([1, 2, 3, 4]), false),
      HashableArgs(OperationPath([1, true, "test"]), OperationPath(["test", 2]), false),
      HashableArgs(OperationPath([1, "test"]), OperationPath([1, "test", 2]), false),
      HashableArgs(OperationPath(), OperationPath(["foo", 1, 2, true, ["test"]]), false)
    ]
  )
  func hashable(args: HashableArgs) {
    expectNoDifference(args.a.hashValue == args.b.hashValue, args.doesMatch)
  }

  struct HashableArgs: Hashable, Sendable {
    let a: OperationPath
    let b: OperationPath
    let doesMatch: Bool

    init(_ a: OperationPath, _ b: OperationPath, _ doesMatch: Bool) {
      self.a = a
      self.b = b
      self.doesMatch = doesMatch
    }
  }

  @Test(
    "Appending",
    arguments: [
      AppendingArgs(OperationPath(), OperationPath(), OperationPath()),
      AppendingArgs(OperationPath([]), OperationPath([]), OperationPath()),
      AppendingArgs(OperationPath([]), OperationPath("foo"), OperationPath("foo")),
      AppendingArgs(OperationPath("foo"), OperationPath([]), OperationPath("foo")),
      AppendingArgs(OperationPath(), OperationPath("foo"), OperationPath("foo")),
      AppendingArgs(
        OperationPath(),
        OperationPath(["foo", "bar"]),
        OperationPath(["foo", "bar"])
      ),
      AppendingArgs(OperationPath("foo"), OperationPath(), OperationPath("foo")),
      AppendingArgs(
        OperationPath(["foo", "bar"]),
        OperationPath(),
        OperationPath(["foo", "bar"])
      ),
      AppendingArgs(OperationPath("foo"), OperationPath("bar"), OperationPath(["foo", "bar"])),
      AppendingArgs(
        OperationPath(["foo", "bar"]),
        OperationPath(1),
        OperationPath(["foo", "bar", 1])
      ),
      AppendingArgs(
        OperationPath(["foo", "bar"]),
        OperationPath([1, true]),
        OperationPath(["foo", "bar", 1, true])
      ),
      AppendingArgs(
        OperationPath("foo"),
        OperationPath(["bar", 1, true]),
        OperationPath(["foo", "bar", 1, true])
      )
    ]
  )
  func appending(_ args: AppendingArgs) {
    expectNoDifference(args.a.appending(args.b), args.expected)
  }

  struct AppendingArgs: Hashable, Sendable {
    let a: OperationPath
    let b: OperationPath
    let expected: OperationPath

    init(_ a: OperationPath, _ b: OperationPath, _ expected: OperationPath) {
      self.a = a
      self.b = b
      self.expected = expected
    }
  }

  @Test(
    "End Index",
    arguments: [
      (OperationPath(), 0),
      (OperationPath([]), 0),
      (OperationPath("foo"), 1),
      (OperationPath(["foo"]), 1),
      (OperationPath(["foo", "bar"]), 2),
      (OperationPath(["foo", "bar", 1]), 3)
    ]
  )
  func endIndex(path: OperationPath, index: Int) {
    expectNoDifference(path.endIndex, index)
  }

  @Test(
    "Subscripting",
    arguments: [
      (OperationPath("bar"), 0, OperationPath.Element("bar")),
      (OperationPath(["bar"]), 0, OperationPath.Element("bar")),
      (OperationPath(["bar", "baz"]), 1, OperationPath.Element("baz"))
    ]
  )
  func subscripting(path: OperationPath, index: Int, readValue: OperationPath.Element) {
    var path = path
    expectNoDifference(path[index], readValue)

    path[index] = OperationPath.Element(0)
    expectNoDifference(path[index], OperationPath.Element(0))
  }

  @Test(
    "Replace Subrange",
    arguments: [
      ReplaceSubrangeArgs(OperationPath("element"), 0..<1, ["foo"], OperationPath("foo")),
      ReplaceSubrangeArgs(OperationPath(), 0..<0, OperationPath("foo"), OperationPath("foo")),
      ReplaceSubrangeArgs(
        OperationPath("bar"),
        1..<1,
        OperationPath("foo"),
        OperationPath(["bar", "foo"])
      ),
      ReplaceSubrangeArgs(
        OperationPath("bar"),
        0..<0,
        OperationPath("foo"),
        OperationPath(["foo", "bar"])
      ),
      ReplaceSubrangeArgs(
        OperationPath(["foo", "bar"]),
        2..<2,
        OperationPath("baz"),
        OperationPath(["foo", "bar", "baz"])
      ),
      ReplaceSubrangeArgs(
        OperationPath(["foo", "bar"]),
        0..<0,
        OperationPath("baz"),
        OperationPath(["baz", "foo", "bar"])
      ),
      ReplaceSubrangeArgs(
        OperationPath(["element", "bar"]),
        0..<1,
        ["foo"],
        OperationPath(["foo", "bar"])
      ),
      ReplaceSubrangeArgs(
        OperationPath(["element", "bar"]),
        1..<2,
        ["baz"],
        OperationPath(["element", "baz"])
      ),
      ReplaceSubrangeArgs(
        OperationPath(["element", "bar"]),
        0..<2,
        ["foo", "baz"],
        OperationPath(["foo", "baz"])
      ),
      ReplaceSubrangeArgs(
        OperationPath(["element", "bar", "baz"]),
        0..<1,
        OperationPath(),
        OperationPath(["bar", "baz"])
      ),
      ReplaceSubrangeArgs(OperationPath("element"), 0..<1, OperationPath(), OperationPath())
    ]
  )
  func replaceSubrange(args: ReplaceSubrangeArgs) {
    var path = args.path
    path.replaceSubrange(args.range, with: args.replacement)
    expectNoDifference(path, args.expected)
  }

  struct ReplaceSubrangeArgs: Hashable, Sendable {
    let path: OperationPath
    let range: Range<Int>
    let replacement: OperationPath
    let expected: OperationPath

    init(
      _ path: OperationPath,
      _ range: Range<Int>,
      _ replacement: OperationPath,
      _ expected: OperationPath
    ) {
      self.path = path
      self.range = range
      self.replacement = replacement
      self.expected = expected
    }
  }

  #if swift(>=6.2) && SWIFT_OPERATION_EXIT_TESTABLE_PLATFORM
    // NB: Parameterized tests don't support exit testing due to the macro expanding an
    // @convention(c) closure. So inline all of this instead.

    @Test("Index Out of Range (Reading)")
    func indexOutOfRangeReading() async {
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath()[0]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath()[1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath()[-1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath()[2983]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath()[-198]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath([])[0]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath([])[1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath([])[-1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath([])[2983]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath([])[18]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath("element")[1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath("element")[1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath("element")[100]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath("element")[13]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath(["element", "bar"])[-1]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath(["element", "bar"])[2]
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        _ = OperationPath(["element"])[1]
      }
    }

    @Test("Index Out of Range (Writing)")
    func indexOutOfRangeWriting() async {
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath()
        p[0] = OperationPath.Element(0)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath()
        p[1] = OperationPath.Element(1)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath()
        p[-1] = OperationPath.Element(-1)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath()
        p[2983] = OperationPath.Element(2983)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath()
        p[2983] = OperationPath.Element(2983)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath()
        p[-198] = OperationPath.Element(-198)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath([])
        p[0] = OperationPath.Element(0)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath([])
        p[1] = OperationPath.Element(1)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath([])
        p[-1] = OperationPath.Element(-1)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath([])
        p[2983] = OperationPath.Element(2983)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath([])
        p[18] = OperationPath.Element(0)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath([])
        p[18] = OperationPath.Element(0)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath("element")
        p[1] = OperationPath.Element(0)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath("element")
        p[1] = OperationPath.Element(0)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath("element")
        p[100] = OperationPath.Element(0)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath("element")
        p[13] = OperationPath.Element(0)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath("element")
        p[13] = OperationPath.Element(0)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath(["element", "bar"])
        p[-1] = OperationPath.Element(0)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath(["element", "bar"])
        p[2] = OperationPath.Element(0)
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var p = OperationPath(["element"])
        p[1] = OperationPath.Element(0)
      }
    }

    @Test("Exits When Replacing Invalid Subrange")
    func exitsWhenReplacingInvalidSubrange() async {
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var path = OperationPath()
        path.replaceSubrange(0..<1, with: [])
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var path = OperationPath("blob")
        path.replaceSubrange(0..<2, with: [])
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var path = OperationPath(["blob", "foo"])
        path.replaceSubrange(0..<3, with: [])
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var path = OperationPath(["blob", "foo"])
        path.replaceSubrange(-1..<3, with: [])
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var path = OperationPath(["blob", "foo"])
        path.replaceSubrange(4..<4, with: [OperationPath.Element("blob 2")])
      }
      await #expect(processExitsWith: .failure, .indexOutOfRange) {
        var path = OperationPath(["blob", "foo"])
        path.replaceSubrange(-1..<1, with: [])
      }
    }
  #endif
}

private struct SomeValue: Hashable, Sendable {
}

extension Comment {
  fileprivate static let indexOutOfRange = Self(rawValue: OperationPath._indexOutOfRangeMessage)
}
