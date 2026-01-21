import MacroTesting
import OperationMacros
import Testing

extension BaseTestSuite {
  @Suite("OperationRequestMacro tests")
  struct OperationRequestMacroTests {
    @Test("Basic Operation")
    func basicOperation() {
      assertMacro {
        """
        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {

          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Void Operation")
    func voidOperation() {
      assertMacro {
        """
        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {

          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Operation With Arguments")
    func operationWithArguments() {
      assertMacro {
        """
        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          let arg2: String
          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Operation With Duplicate Arguments")
    func operationWithDuplicateArguments() {
      assertMacro {
        """
        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          let arg2: String
          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Operation With Default Arguments")
    func operationWithDefaultArguments() {
      assertMacro {
        """
        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Operation With Variadic Arguments")
    func operationWithVariadicArguments() {
      assertMacro {
        """
        @OperationRequest
        func something(args: Int...) -> Int {
          args.reduce(0, +)
        }
        """
      } diagnostics: {
        """
        @OperationRequest
        func something(args: Int...) -> Int {
                       ┬───────────
                       ╰─ 🛑 Variadic arguments are not supported.
          args.reduce(0, +)
        }
        """
      }
    }

    @Test("Operation With Inout Argument")
    func operationWithInoutArgument() {
      assertMacro {
        """
        @OperationRequest
        func something(arg: inout Int) -> Int {
          arg += 1
          return arg
        }
        """
      } diagnostics: {
        """
        @OperationRequest
        func something(arg: inout Int) -> Int {
                       ┬─────────────
                       ╰─ 🛑 Inout arguments are not supported.
          arg += 1
          return arg
        }
        """
      }
    }

    @Test("Operation With Context")
    func operationWithContext() {
      assertMacro {
        """
        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Operation With Context And Continuation")
    func operationWithContextAndContinuation() {
      assertMacro {
        """
        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Operation With Context, Continuation, And Isolation")
    func operationWithContextAndContinuationAndIsolation() {
      assertMacro {
        """
        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Operation With Only Reserved Arguments")
    func operationWithOnlyReservedArguments() {
      assertMacro {
        """
        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {

          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Static Operation")
    func staticOperation() {
      assertMacro {
        """
        struct Foo {
          @OperationRequest
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
            __macro_local_9somethingfMu_(arg: arg, __macro_local_4typefMu_: _OperationHashableMetatype(type: Foo.self))
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
            let arg: Int
            let __macro_local_4typefMu_: _OperationHashableMetatype<Foo>
            var _debugTypeName: String {
              "Foo.something"
            }
            func run(
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

    @Test("Metatype Operation")
    func metatypeOperation() {
      assertMacro {
        """
        struct Foo {
          static let value = 42

          @OperationRequest
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
            __macro_local_9somethingfMu_(__macro_local_4typefMu_: _OperationHashableMetatype(type: Foo.self))
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
            let __macro_local_4typefMu_: _OperationHashableMetatype<Foo>
            var _debugTypeName: String {
              "Foo.something"
            }
            func run(
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

    @Test("Extension Metatype Operation")
    func extensionMetatypeOperation() {
      assertMacro {
        """
        struct Foo {
        }

        extension Foo {
          @OperationRequest
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
            __macro_local_9somethingfMu_(arg: arg, __macro_local_4typefMu_: _OperationHashableMetatype(type: Foo.self))
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
            let arg: Int
            let __macro_local_4typefMu_: _OperationHashableMetatype<Foo>
            var _debugTypeName: String {
              "Foo.something"
            }
            func run(
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

    @Test("Member Operation")
    func memberOperation() {
      assertMacro {
        """
        struct Foo {
          let value: Int

          @OperationRequest
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

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
            let arg: Int
            let __macro_local_4typefMu_: Foo
            var _debugTypeName: String {
              "Foo.something"
            }
            func run(
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

    @Test("Extension Member Operation")
    func extensionMemberOperation() {
      assertMacro {
        """
        struct Foo {
          let value: Int
        }

        extension Foo {
          @OperationRequest
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

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
            let arg: Int
            let __macro_local_4typefMu_: Foo
            var _debugTypeName: String {
              "Foo.something"
            }
            func run(
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

    @Test("Nested Function Operation")
    func nestedFunctionOperation() {
      assertMacro {
        """
        func foo() {
          @OperationRequest
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

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
            let arg: Int
            var _debugTypeName: String {
              "something"
            }
            func run(
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

    @Test("Nested Function In Type Operation")
    func nestedFunctionInTypeOperation() {
      assertMacro {
        """
        struct Foo {
          func foo() {
            @OperationRequest
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

            nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
              let arg: Int
              let __macro_local_4typefMu_: Foo
              var _debugTypeName: String {
                "Foo.something"
              }
              func run(
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

    @Test("Access Control Operation")
    func accessControlOperation() {
      assertMacro {
        """
        @OperationRequest
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

        public nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          public var _debugTypeName: String {
            "something"
          }
          public func run(
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
        @OperationRequest
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

        private nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          var _debugTypeName: String {
            "something"
          }
          func run(
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
        @OperationRequest
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

        fileprivate nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          fileprivate var _debugTypeName: String {
            "something"
          }
          fileprivate func run(
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

    @Test("Availability Operation")
    func availabilityOperation() {
      assertMacro {
        """
        @OperationRequest
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
        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          var _debugTypeName: String {
            "something"
          }
          func run(
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
        @OperationRequest
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
        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Throwing Operation")
    func throwingOperation() {
      assertMacro {
        """
        @OperationRequest
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, any Error>
        ) throws -> Int {
          arg
        }
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Typed-Throwing Operation")
    func typedThrowingOperation() {
      assertMacro {
        """
        struct MyError: Error {}

        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Async Throwing Operation")
    func asyncThrowingOperation() {
      assertMacro {
        """
        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Static Async Throwing Operation")
    func staticAsyncThrowingOperation() {
      assertMacro {
        """
        struct Foo {
          @OperationRequest
          static func something(
            arg: Int,
            context: OperationContext,
            continuation: OperationContinuation<Int, any Error>
          ) async throws -> Int {
            arg
          }
        }
        """
      } expansion: {
        """
        struct Foo {
          static func something(
            arg: Int,
            context: OperationContext,
            continuation: OperationContinuation<Int, any Error>
          ) async throws -> Int {
            arg
          }

          static nonisolated func $something(arg: Int,) -> __macro_local_9somethingfMu_ {
            __macro_local_9somethingfMu_(arg: arg, __macro_local_4typefMu_: _OperationHashableMetatype(type: Foo.self))
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
            let arg: Int
            let __macro_local_4typefMu_: _OperationHashableMetatype<Foo>
            var _debugTypeName: String {
              "Foo.something"
            }
            func run(
              isolation: isolated (any Actor)?,
              in context: OperationCore.OperationContext,
              with continuation: OperationCore.OperationContinuation<Int, any Error>
            ) async throws -> Int {
              try await __macro_local_4typefMu_.type.something(arg: self.arg, context: context, continuation: continuation)
            }
          }
        }
        """
      }
    }

    @Test("Async Typed-Throws Operation")
    func asyncTypedThrowsOperation() {
      assertMacro {
        """
        struct MyError: Error {}

        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
          let arg: Int
          var _debugTypeName: String {
            "something"
          }
          func run(
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

    @Test("Static Nested In Inner Type Operation")
    func staticNestedInInnerTypeOperation() {
      assertMacro {
        """
        struct Foo {
          struct Bar {
            static let blob = 42
          }
        }

        extension Foo.Bar {
          @OperationRequest
          static func something() async throws -> Int {
            Self.blob
          }
        }
        """
      } expansion: {
        """
        struct Foo {
          struct Bar {
            static let blob = 42
          }
        }

        extension Foo.Bar {
          static func something() async throws -> Int {
            Self.blob
          }

          static nonisolated var $something: __macro_local_9somethingfMu_ {
            __macro_local_9somethingfMu_(__macro_local_4typefMu_: _OperationHashableMetatype(type: Foo.Bar.self))
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.OperationRequest {
            let __macro_local_4typefMu_: _OperationHashableMetatype<Foo.Bar>
            var _debugTypeName: String {
              "Foo.Bar.something"
            }
            func run(
              isolation: isolated (any Actor)?,
              in context: OperationCore.OperationContext,
              with continuation: OperationCore.OperationContinuation<Int, any Error>
            ) async throws -> Int {
              try await __macro_local_4typefMu_.type.something()
            }
          }
        }
        """
      }
    }

    @Test("Generic Operation")
    func genericOperation() {
      assertMacro {
        """
        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_<T: Creatable>: OperationCore.OperationRequest {

          var _debugTypeName: String {
            "something"
          }
          func run(
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
        @OperationRequest
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

        nonisolated struct __macro_local_9somethingfMu_<T: Creatable>: OperationCore.OperationRequest {

          var _debugTypeName: String {
            "something"
          }
          func run(
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
        @OperationRequest
        struct Foo {
        }
        """
      } diagnostics: {
        """
        @OperationRequest
        ╰─ 🛑 @OperationRequest can only be applied to functions.
        struct Foo {
        }
        """
      }
    }

    @Test("Operation With Invalid Isolation Parameter")
    func operationWithInvalidIsolationParameter() {
      assertMacro {
        """
        @OperationRequest
        func something(isolation: Int) -> Int {
          arg
        }
        """
      } diagnostics: {
        """
        @OperationRequest
        func something(isolation: Int) -> Int {
                       ┬─────────────
                       ╰─ 🛑 'isolation' argument must be 'isolated (any Actor)?'.
          arg
        }
        """
      }
    }

    @Test("Operation With Invalid Context Parameter")
    func operationWithInvalidContextParameter() {
      assertMacro {
        """
        @OperationRequest
        func something(context: Int) -> Int {
          arg
        }
        """
      } diagnostics: {
        """
        @OperationRequest
        func something(context: Int) -> Int {
                       ┬───────────
                       ╰─ 🛑 'context' argument must be of type 'OperationContext'.
          arg
        }
        """
      }
    }

    @Test("Operation With Invalid Continuation Parameter")
    func operationWithInvalidContinuationParameter() {
      assertMacro {
        """
        @OperationRequest
        func something(continuation: Int) -> Int {
          arg
        }
        """
      } diagnostics: {
        """
        @OperationRequest
        func something(continuation: Int) -> Int {
                       ┬────────────────
                       ╰─ 🛑 'continuation' argument must be of type 'OperationContinuation<Int, Never>'
          arg
        }
        """
      }
    }
  }
}
