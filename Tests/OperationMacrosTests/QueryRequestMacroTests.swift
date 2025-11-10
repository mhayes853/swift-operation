import MacroTesting
import OperationMacros
import Testing

extension BaseTestSuite {
  @Suite("QueryRequestMacro tests")
  struct QueryRequestMacroTests {
    @Test("Basic Query")
    func basicQuery() {
      assertMacro {
        """
        @QueryRequest
        func something() -> Int {
          42
        }
        """
      } expansion: {
        """
        func something() -> Int {
          42
        }

        nonisolated var $something: __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_()
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {

          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something()
          }
        }
        """
      }
    }

    @Test("Void Query")
    func voidQuery() {
      assertMacro {
        """
        @QueryRequest
        func something() {
          42
        }
        """
      } expansion: {
        """
        func something() {
          42
        }

        nonisolated var $something: __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_()
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {

          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Void, Never>
          ) async  {
            something()
          }
        }
        """
      }
    }

    @Test("Query With Arguments")
    func queryWithArguments() {
      assertMacro {
        """
        @QueryRequest
        func something(arg: Int, with arg2: String) -> Int {
          arg2.count + arg
        }
        """
      } expansion: {
        """
        func something(arg: Int, with arg2: String) -> Int {
          arg2.count + arg
        }

        nonisolated func $something(arg: Int, with arg2: String) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg, arg2: arg2)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          let arg2: String
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg, with: self.arg2)
          }
        }
        """
      }
    }

    @Test("Query With Duplicate Arguments")
    func queryWithDuplicateArguments() {
      assertMacro {
        """
        @QueryRequest
        func something(with arg: Int, with arg2: String) -> Int {
          arg2.count + arg
        }
        """
      } expansion: {
        """
        func something(with arg: Int, with arg2: String) -> Int {
          arg2.count + arg
        }

        nonisolated func $something(with arg: Int, with arg2: String) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg, arg2: arg2)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          let arg2: String
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(with: self.arg, with: self.arg2)
          }
        }
        """
      }
    }

    @Test("Query With Default Arguments")
    func queryWithDefaultArguments() {
      assertMacro {
        """
        @QueryRequest
        func something(arg: Int = 0) -> Int {
          arg
        }
        """
      } expansion: {
        """
        func something(arg: Int = 0) -> Int {
          arg
        }

        nonisolated func $something(arg: Int = 0) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg)
          }
        }
        """
      }
    }

    @Test("Query With Variadic Arguments")
    func queryWithVariadicArguments() {
      assertMacro {
        """
        @QueryRequest
        func something(args: Int...) -> Int {
          args.reduce(0, +)
        }
        """
      } diagnostics: {
        """
        @QueryRequest
        func something(args: Int...) -> Int {
                       ┬───────────
                       ╰─ 🛑 Variadic arguments are not supported.
          args.reduce(0, +)
        }
        """
      }
    }

    @Test("Query With Inout Argument")
    func queryWithInoutArgument() {
      assertMacro {
        """
        @QueryRequest
        func something(arg: inout Int) -> Int {
          arg += 1
          return arg
        }
        """
      } diagnostics: {
        """
        @QueryRequest
        func something(arg: inout Int) -> Int {
                       ┬─────────────
                       ╰─ 🛑 Inout arguments are not supported.
          arg += 1
          return arg
        }
        """
      }
    }

    @Test("Query With Context")
    func queryWithContext() {
      assertMacro {
        """
        @QueryRequest
        func something(arg: Int, context: OperationContext) -> Int {
          arg
        }
        """
      } diagnostics: {
        """

        """
      } expansion: {
        """
        func something(arg: Int, context: OperationContext) -> Int {
          arg
        }

        nonisolated func $something(arg: Int,) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg, context: context)
          }
        }
        """
      }
    }

    @Test("Query With Context And Continuation")
    func queryWithContextAndContinuation() {
      assertMacro {
        """
        @QueryRequest
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, Never>
        ) -> Int {
          arg
        }
        """
      } expansion: {
        """
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, Never>
        ) -> Int {
          arg
        }

        nonisolated func $something(arg: Int,) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Query With Context, Continuation, And Isolation")
    func queryWithContextAndContinuationAndIsolation() {
      assertMacro {
        """
        @QueryRequest
        func something(
          arg: Int,
          isolation: isolated (any Actor)?,
          context: OperationContext,
          continuation: OperationContinuation<Int, Never>
        ) -> Int {
          arg
        }
        """
      } expansion: {
        """
        func something(
          arg: Int,
          isolation: isolated (any Actor)?,
          context: OperationContext,
          continuation: OperationContinuation<Int, Never>
        ) -> Int {
          arg
        }

        nonisolated func $something(arg: Int,) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg, isolation: isolation, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Query With Only Reserved Arguments")
    func queryWithOnlyReservedArguments() {
      assertMacro {
        """
        @QueryRequest
        func something(
          isolation: isolated (any Actor)?,
          context: OperationContext,
          continuation: OperationContinuation<Int, Never>
        ) -> Int {
          42
        }
        """
      } expansion: {
        """
        func something(
          isolation: isolated (any Actor)?,
          context: OperationContext,
          continuation: OperationContinuation<Int, Never>
        ) -> Int {
          42
        }

        nonisolated var $something: __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_()
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {

          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(isolation: isolation, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Static Query")
    func staticQuery() {
      assertMacro {
        """
        struct Foo {
          @QueryRequest
          static func something(arg: Int) -> Int {
            arg
          }
        }
        """
      } expansion: {
        """
        struct Foo {
          static func something(arg: Int) -> Int {
            arg
          }

          static nonisolated func $something(arg: Int) -> __macro_local_9somethingfMu_ {
            __macro_local_9somethingfMu_(arg: arg, __macro_local_4typefMu_: _OperationHashableMetatype(type: Self.self))
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
            let arg: Int
            let __macro_local_4typefMu_: _OperationHashableMetatype<Foo>
            var path: OperationCore.OperationPath {
            OperationCore.OperationPath(self)
            }
            func fetch(
              isolation: isolated (any Actor)?,
              in context: OperationCore.OperationContext,
              with continuation: OperationCore.OperationContinuation<Int, Never>
            ) async -> Int {
              __macro_local_4typefMu_.type.something(arg: self.arg)
            }
          }
        }
        """
      }
    }

    @Test("Metatype Query")
    func metatypeQuery() {
      assertMacro {
        """
        struct Foo {
          static let value = 42

          @QueryRequest
          static func something() -> Int {
            Self.value
          }
        }
        """
      } expansion: {
        """
        struct Foo {
          static let value = 42
          static func something() -> Int {
            Self.value
          }

          static nonisolated var $something: __macro_local_9somethingfMu_ {
            __macro_local_9somethingfMu_(__macro_local_4typefMu_: _OperationHashableMetatype(type: Self.self))
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
            let __macro_local_4typefMu_: _OperationHashableMetatype<Foo>
            var path: OperationCore.OperationPath {
            OperationCore.OperationPath(self)
            }
            func fetch(
              isolation: isolated (any Actor)?,
              in context: OperationCore.OperationContext,
              with continuation: OperationCore.OperationContinuation<Int, Never>
            ) async -> Int {
              __macro_local_4typefMu_.type.something()
            }
          }
        }
        """
      }
    }

    @Test("Extension Metatype Query")
    func extensionMetatypeQuery() {
      assertMacro {
        """
        struct Foo {
        }

        extension Foo {
          @QueryRequest
          static func something(arg: Int) -> Int {
            arg
          }
        }
        """
      } expansion: {
        """
        struct Foo {
        }

        extension Foo {
          static func something(arg: Int) -> Int {
            arg
          }

          static nonisolated func $something(arg: Int) -> __macro_local_9somethingfMu_ {
            __macro_local_9somethingfMu_(arg: arg, __macro_local_4typefMu_: _OperationHashableMetatype(type: Self.self))
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
            let arg: Int
            let __macro_local_4typefMu_: _OperationHashableMetatype<Foo>
            var path: OperationCore.OperationPath {
            OperationCore.OperationPath(self)
            }
            func fetch(
              isolation: isolated (any Actor)?,
              in context: OperationCore.OperationContext,
              with continuation: OperationCore.OperationContinuation<Int, Never>
            ) async -> Int {
              __macro_local_4typefMu_.type.something(arg: self.arg)
            }
          }
        }
        """
      }
    }

    @Test("Member Query")
    func memberQuery() {
      assertMacro {
        """
        struct Foo {
          let value: Int

          @QueryRequest
          func something(arg: Int) -> Int {
            self.value
          }
        }
        """
      } expansion: {
        """
        struct Foo {
          let value: Int
          func something(arg: Int) -> Int {
            self.value
          }

          nonisolated func $something(arg: Int) -> __macro_local_9somethingfMu_ {
            __macro_local_9somethingfMu_(arg: arg, __macro_local_4typefMu_: self)
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
            let arg: Int
            let __macro_local_4typefMu_: Foo
            var path: OperationCore.OperationPath {
            OperationCore.OperationPath(self)
            }
            func fetch(
              isolation: isolated (any Actor)?,
              in context: OperationCore.OperationContext,
              with continuation: OperationCore.OperationContinuation<Int, Never>
            ) async -> Int {
              __macro_local_4typefMu_.something(arg: self.arg)
            }
          }
        }
        """
      }
    }

    @Test("Extension Member Query")
    func extensionMemberQuery() {
      assertMacro {
        """
        struct Foo {
          let value: Int
        }

        extension Foo {
          @QueryRequest
          func something(arg: Int) -> Int {
            self.value
          }
        }
        """
      } expansion: {
        """
        struct Foo {
          let value: Int
        }

        extension Foo {
          func something(arg: Int) -> Int {
            self.value
          }

          nonisolated func $something(arg: Int) -> __macro_local_9somethingfMu_ {
            __macro_local_9somethingfMu_(arg: arg, __macro_local_4typefMu_: self)
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
            let arg: Int
            let __macro_local_4typefMu_: Foo
            var path: OperationCore.OperationPath {
            OperationCore.OperationPath(self)
            }
            func fetch(
              isolation: isolated (any Actor)?,
              in context: OperationCore.OperationContext,
              with continuation: OperationCore.OperationContinuation<Int, Never>
            ) async -> Int {
              __macro_local_4typefMu_.something(arg: self.arg)
            }
          }
        }
        """
      }
    }

    @Test("Nested Function Query")
    func nestedFunctionQuery() {
      assertMacro {
        """
        func foo() {
          @QueryRequest
          func something(arg: Int) -> Int {
            self.value
          }
        }
        """
      } expansion: {
        """
        func foo() {
          func something(arg: Int) -> Int {
            self.value
          }

          nonisolated func $something(arg: Int) -> __macro_local_9somethingfMu_ {
            __macro_local_9somethingfMu_(arg: arg)
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
            let arg: Int
            var path: OperationCore.OperationPath {
            OperationCore.OperationPath(self)
            }
            func fetch(
              isolation: isolated (any Actor)?,
              in context: OperationCore.OperationContext,
              with continuation: OperationCore.OperationContinuation<Int, Never>
            ) async -> Int {
              something(arg: self.arg)
            }
          }
        }
        """
      }
    }

    @Test("Nested Function In Type Query")
    func nestedFunctionInTypeQuery() {
      assertMacro {
        """
        struct Foo {
          func foo() {
            @QueryRequest
            func something(arg: Int) -> Int {
              self.value
            }
          }
        }
        """
      } expansion: {
        """
        struct Foo {
          func foo() {
            func something(arg: Int) -> Int {
              self.value
            }

            nonisolated func $something(arg: Int) -> __macro_local_9somethingfMu_ {
              __macro_local_9somethingfMu_(arg: arg, __macro_local_4typefMu_: self)
            }

            nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
              let arg: Int
              let __macro_local_4typefMu_: Foo
              var path: OperationCore.OperationPath {
              OperationCore.OperationPath(self)
              }
              func fetch(
                isolation: isolated (any Actor)?,
                in context: OperationCore.OperationContext,
                with continuation: OperationCore.OperationContinuation<Int, Never>
              ) async -> Int {
                __macro_local_4typefMu_.something(arg: self.arg)
              }
            }
          }
        }
        """
      }
    }

    @Test("Access Control Query")
    func accessControlQuery() {
      assertMacro {
        """
        @QueryRequest
        public func something(arg: Int) -> Int {
          arg
        }
        """
      } expansion: {
        """
        public func something(arg: Int) -> Int {
          arg
        }

        public nonisolated func $something(arg: Int) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        public nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          public var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          public func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg)
          }
        }
        """
      }
      assertMacro {
        """
        @QueryRequest
        private func something(arg: Int) -> Int {
          arg
        }
        """
      } expansion: {
        """
        private func something(arg: Int) -> Int {
          arg
        }

        private nonisolated func $something(arg: Int) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        private nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg)
          }
        }
        """
      }
      assertMacro {
        """
        @QueryRequest
        fileprivate func something(arg: Int) -> Int {
          arg
        }
        """
      } expansion: {
        """
        fileprivate func something(arg: Int) -> Int {
          arg
        }

        fileprivate nonisolated func $something(arg: Int) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        fileprivate nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          fileprivate var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          fileprivate func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg)
          }
        }
        """
      }
    }

    @Test("Availability Query")
    func availabilityQuery() {
      assertMacro {
        """
        @QueryRequest
        @available(iOS 13.0, *)
        func something(arg: Int) -> Int {
          arg
        }
        """
      } expansion: {
        """
        @available(iOS 13.0, *)
        func something(arg: Int) -> Int {
          arg
        }

        @available(iOS 13.0, *)
        nonisolated func $something(arg: Int) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        @available(iOS 13.0, *)
        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg)
          }
        }
        """
      }

      assertMacro {
        """
        @QueryRequest
        @available(iOS 13.0, *)
        @available(tvOS 13.0, *)
        func something(arg: Int) -> Int {
          arg
        }
        """
      } expansion: {
        """
        @available(iOS 13.0, *)
        @available(tvOS 13.0, *)
        func something(arg: Int) -> Int {
          arg
        }

        @available(iOS 13.0, *)
        @available(tvOS 13.0, *)
        nonisolated func $something(arg: Int) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        @available(iOS 13.0, *)
        @available(tvOS 13.0, *)
        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg)
          }
        }
        """
      }
    }

    @Test("Throwing Query")
    func throwingQuery() {
      assertMacro {
        """
        @QueryRequest
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, any Error>
        ) throws -> Int {
          arg
        }
        """
      } diagnostics: {
        """

        """
      } expansion: {
        """
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, any Error>
        ) throws -> Int {
          arg
        }

        nonisolated func $something(arg: Int,) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, any Error>
          ) async throws -> Int {
            try something(arg: self.arg, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Typed-Throwing Query")
    func typedThrowingQuery() {
      assertMacro {
        """
        struct MyError: Error {}

        @QueryRequest
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, MyError>
        ) throws(MyError) -> Int {
          arg
        }
        """
      } expansion: {
        """
        struct MyError: Error {}
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, MyError>
        ) throws(MyError) -> Int {
          arg
        }

        nonisolated func $something(arg: Int,) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, MyError>
          ) async throws(MyError) -> Int {
            try something(arg: self.arg, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Async Throwing Query")
    func asyncThrowingQuery() {
      assertMacro {
        """
        @QueryRequest
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, any Error>
        ) async throws -> Int {
          arg
        }
        """
      } expansion: {
        """
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, any Error>
        ) async throws -> Int {
          arg
        }

        nonisolated func $something(arg: Int,) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, any Error>
          ) async throws -> Int {
            try await something(arg: self.arg, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Async Typed-Throws Query")
    func asyncTypedThrowsQuery() {
      assertMacro {
        """
        struct MyError: Error {}

        @QueryRequest
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, MyError>
        ) async throws(MyError) -> Int {
          arg
        }
        """
      } expansion: {
        """
        struct MyError: Error {}
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, MyError>
        ) async throws(MyError) -> Int {
          arg
        }

        nonisolated func $something(arg: Int,) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, MyError>
          ) async throws(MyError) -> Int {
            try await something(arg: self.arg, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Generic Query")
    func genericQuery() {
      assertMacro {
        """
        @QueryRequest
        func something<T: Creatable>() -> sending T {
          T()
        }
        """
      } expansion: {
        """
        func something<T: Creatable>() -> sending T {
          T()
        }

        nonisolated func $something<T: Creatable>() -> __macro_local_9somethingfMu_<T> {
          __macro_local_9somethingfMu_<T>()
        }

        nonisolated struct __macro_local_9somethingfMu_<T: Creatable>: OperationCore.QueryRequest, Hashable {

          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<T, Never>
          ) async -> sending T {
            something()
          }
        }
        """
      }
      assertMacro {
        """
        @QueryRequest
        func something<T: Creatable>() -> T {
          T()
        }
        """
      } expansion: {
        """
        func something<T: Creatable>() -> T {
          T()
        }

        nonisolated func $something<T: Creatable>() -> __macro_local_9somethingfMu_<T> {
          __macro_local_9somethingfMu_<T>()
        }

        nonisolated struct __macro_local_9somethingfMu_<T: Creatable>: OperationCore.QueryRequest, Hashable {

          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<T, Never>
          ) async -> T {
            something()
          }
        }
        """
      }
    }

    @Test("Wrong Declaration")
    func wrongDeclaration() {
      assertMacro {
        """
        @QueryRequest
        struct Foo {
        }
        """
      } diagnostics: {
        """
        @QueryRequest
        ╰─ 🛑 @OperationRequest can only be applied to functions.
        struct Foo {
        }
        """
      }
    }

    @Test("Query With Invalid Isolation Parameter")
    func queryWithInvalidIsolationParameter() {
      assertMacro {
        """
        @QueryRequest
        func something(isolation: Int) -> Int {
          arg
        }
        """
      } diagnostics: {
        """
        @QueryRequest
        func something(isolation: Int) -> Int {
                       ┬─────────────
                       ╰─ 🛑 'isolation' argument must be 'isolated (any Actor)?'.
          arg
        }
        """
      }
    }

    @Test("Query With Invalid Context Parameter")
    func queryWithInvalidContextParameter() {
      assertMacro {
        """
        @QueryRequest
        func something(context: Int) -> Int {
          arg
        }
        """
      } diagnostics: {
        """
        @QueryRequest
        func something(context: Int) -> Int {
                       ┬───────────
                       ╰─ 🛑 'context' argument must be of type 'OperationContext'.
          arg
        }
        """
      }
    }

    @Test("Query With Invalid Continuation Parameter")
    func queryWithInvalidContinuationParameter() {
      assertMacro {
        """
        @QueryRequest
        func something(continuation: Int) -> Int {
          arg
        }
        """
      } diagnostics: {
        """
        @QueryRequest
        func something(continuation: Int) -> Int {
                       ┬────────────────
                       ╰─ 🛑 'continuation' argument must be of type 'OperationContinuation<Int, Never>'
          arg
        }
        """
      }
    }

    @Test("Query With Path Inferred From ID")
    func queryWithPathInferredFromID() {
      assertMacro {
        """
        @QueryRequest(path: .inferredFromIdentifiable)
        func something(id: Int) -> Int {
          id
        }
        """
      } expansion: {
        """
        func something(id: Int) -> Int {
          id
        }

        nonisolated func $something(id: Int) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(id: id)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Identifiable {
          let id: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(id)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(id: self.id)
          }
        }
        """
      }
    }

    @Test("Query With Path Inferred From ID, No ID Argument")
    func queryWithPathInferredFromIDNoIDArgument() {
      assertMacro {
        """
        @QueryRequest(path: .inferredFromIdentifiable)
        func something(arg: Int) -> Int {
          arg
        }
        """
      } diagnostics: {
        """
        @QueryRequest(path: .inferredFromIdentifiable)
        ╰─ 🛑 An 'id' argument is required when using '.inferredFromIdentifiable'
        func something(arg: Int) -> Int {
          arg
        }
        """
      }
    }

    @Test("Query With Custom Path Synthesis")
    func queryWithCustomPathSynthesis() {
      assertMacro {
        """
        @QueryRequest(path: .custom { OperationPath("blob") })
        func something() -> Int {
          42
        }
        """
      } expansion: {
        """
        func something() -> Int {
          42
        }

        nonisolated var $something: __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_()
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest {

          var path: OperationCore.OperationPath {
          makePath()
          }
          private func makePath() -> OperationCore.OperationPath {
            OperationPath("blob")
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something()
          }
        }
        """
      }
      assertMacro {
        """
        @QueryRequest(
          path: .custom { () -> OperationPath in
            OperationPath("blob")
          }
        )
        func something() -> Int {
          42
        }
        """
      } expansion: {
        """
        func something() -> Int {
          42
        }

        nonisolated var $something: __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_()
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest {

          var path: OperationCore.OperationPath {
          makePath()
          }
          private func makePath() -> OperationCore.OperationPath {

              OperationPath("blob")
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something()
          }
        }
        """
      }
      assertMacro {
        """
        @QueryRequest(path: .custom { (arg: Int) in ["blob", arg] })
        func something(arg: Int) -> Int {
          arg
        }
        """
      } expansion: {
        """
        func something(arg: Int) -> Int {
          arg
        }

        nonisolated func $something(arg: Int) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest {
          let arg: Int
          var path: OperationCore.OperationPath {
          makePath(arg: arg)
          }
          private func makePath(arg: Int) -> OperationCore.OperationPath {
            ["blob", arg]
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg)
          }
        }
        """
      }
      assertMacro {
        """
        @QueryRequest(path: .custom { (arg: Int) in ["blob", arg] })
        func something(arg: Int, context: OperationContext) -> Int {
          arg
        }
        """
      } expansion: {
        """
        func something(arg: Int, context: OperationContext) -> Int {
          arg
        }

        nonisolated func $something(arg: Int,) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest {
          let arg: Int
          var path: OperationCore.OperationPath {
          makePath(arg: arg)
          }
          private func makePath(arg: Int) -> OperationCore.OperationPath {
            ["blob", arg]
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg, context: context)
          }
        }
        """
      }
      assertMacro {
        """
        @QueryRequest(path: .custom { (arg: Int, arg2: String) in ["blob", arg, arg2] })
        func something(arg: Int, arg2: String) -> Int {
          arg
        }
        """
      } expansion: {
        """
        func something(arg: Int, arg2: String) -> Int {
          arg
        }

        nonisolated func $something(arg: Int, arg2: String) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg, arg2: arg2)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest {
          let arg: Int
          let arg2: String
          var path: OperationCore.OperationPath {
          makePath(arg: arg, arg2: arg2)
          }
          private func makePath(arg: Int, arg2: String) -> OperationCore.OperationPath {
            ["blob", arg, arg2]
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg, arg2: self.arg2)
          }
        }
        """
      }
    }

    @Test("Query With Custom Path Synthesis, Invalid Arguments")
    func queryWithCustomPathSynthesisInvalidArguments() {
      assertMacro {
        """
        @QueryRequest(path: .custom { OperationPath("blob") })
        func something(arg: Int) -> Int {
          42
        }
        """
      } diagnostics: {
        """
        @QueryRequest(path: .custom { OperationPath("blob") })
                                    ┬────────────────────────
                                    ╰─ 🛑 Custom path closure must have arguments '(arg: Int)'
        func something(arg: Int) -> Int {
          42
        }
        """
      }
      assertMacro {
        """
        @QueryRequest(path: .custom { (arg: String) in OperationPath(arg) })
        func something(arg: Int) -> Int {
          42
        }
        """
      } diagnostics: {
        """
        @QueryRequest(path: .custom { (arg: String) in OperationPath(arg) })
                                    ┬──────────────────────────────────────
                                    ╰─ 🛑 Custom path closure must have arguments '(arg: Int)'
        func something(arg: Int) -> Int {
          42
        }
        """
      }
      assertMacro {
        """
        @QueryRequest(path: .custom { (arg: String, arg2: Int) in [arg, arg2] })
        func something(arg: Int) -> Int {
          42
        }
        """
      } diagnostics: {
        """
        @QueryRequest(path: .custom { (arg: String, arg2: Int) in [arg, arg2] })
                                    ┬──────────────────────────────────────────
                                    ╰─ 🛑 Custom path closure must have arguments '(arg: Int)'
        func something(arg: Int) -> Int {
          42
        }
        """
      }
      assertMacro {
        """
        @QueryRequest(path: .custom { (arg1: Int) in [arg] })
        func something(arg: Int) -> Int {
          42
        }
        """
      } diagnostics: {
        """
        @QueryRequest(path: .custom { (arg1: Int) in [arg] })
                                    ┬───────────────────────
                                    ╰─ 🛑 Custom path closure must have arguments '(arg: Int)'
        func something(arg: Int) -> Int {
          42
        }
        """
      }
      assertMacro {
        """
        @QueryRequest(path: .custom { (arg: Int) in [arg] })
        func something(arg: Int, arg2: String) -> Int {
          42
        }
        """
      } diagnostics: {
        """
        @QueryRequest(path: .custom { (arg: Int) in [arg] })
                                    ┬──────────────────────
                                    ╰─ 🛑 Custom path closure must have arguments '(arg: Int, arg2: String)'
        func something(arg: Int, arg2: String) -> Int {
          42
        }
        """
      }
    }

    @Test("Query With Path Argument")
    func queryWithPathArgument() async {
      assertMacro {
        """
        @QueryRequest
        func something(path: OperationPath) -> Int {
          42
        }
        """
      } expansion: {
        """
        func something(path: OperationPath) -> Int {
          42
        }

        nonisolated var $something: __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_()
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.QueryRequest, Hashable {

          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func fetch(
            isolation: isolated (any Actor)?,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(path: path)
          }
        }
        """
      }
    }

    @Test("Query With Invalid Path Argument")
    func queryWithInvalidPathArgument() async {
      assertMacro {
        """
        @QueryRequest
        func something(path: Int) -> Int {
          42
        }
        """
      } diagnostics: {
        """
        @QueryRequest
        func something(path: Int) -> Int {
                       ┬────────
                       ╰─ 🛑 'path' argument must be of type 'OperationPath'
          42
        }
        """
      }
    }
  }
}
