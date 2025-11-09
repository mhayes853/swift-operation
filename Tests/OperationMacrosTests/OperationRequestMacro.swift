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

        var $something: SomethingOperation {
          SomethingOperation()
        }

        struct SomethingOperation: OperationRequest {

          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, Never>
          ) -> Int {
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

        var $something: SomethingOperation {
          SomethingOperation()
        }

        struct SomethingOperation: OperationRequest {

          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Void, Never>
          )  {
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

        func $something(arg: Int, with arg2: String) -> SomethingOperation {
          SomethingOperation(arg: arg, arg2: arg2)
        }

        struct SomethingOperation: OperationRequest {
          let arg: Int
          let arg2: String
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, Never>
          ) -> Int {
            something(arg: arg, with: arg2)
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

        func $something(with arg: Int, with arg2: String) -> SomethingOperation {
          SomethingOperation(arg: arg, arg2: arg2)
        }

        struct SomethingOperation: OperationRequest {
          let arg: Int
          let arg2: String
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, Never>
          ) -> Int {
            something(with: arg, with: arg2)
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

        func $something(arg: Int = 0) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        struct SomethingOperation: OperationRequest {
          let arg: Int
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, Never>
          ) -> Int {
            something(arg: arg)
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

        func $something(arg: Int,) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        struct SomethingOperation: OperationRequest {
          let arg: Int
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, Never>
          ) -> Int {
            something(arg: arg, context: context)
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

        func $something(arg: Int,) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        struct SomethingOperation: OperationRequest {
          let arg: Int
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, Never>
          ) -> Int {
            something(arg: arg, context: context, continuation: continuation)
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

        func $something(arg: Int,) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        struct SomethingOperation: OperationRequest {
          let arg: Int
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, Never>
          ) -> Int {
            something(arg: arg, isolation: isolation, context: context, continuation: continuation)
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

          static func $something(arg: Int) -> SomethingOperation {
            SomethingOperation(arg: arg, __macro_local_4typefMu_: Self.self)
          }

          struct SomethingOperation: OperationRequest {
            let arg: Int
            let __macro_local_4typefMu_: Foo.Type
            func run(
              isolation: isolated (any Actor)?,
              in context: OperationContext,
              with continuation: OperationContinuation<Int, Never>
            ) -> Int {
              __macro_local_4typefMu_.something(arg: arg)
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

          static var $something: SomethingOperation {
            SomethingOperation(__macro_local_4typefMu_: Self.self)
          }

          struct SomethingOperation: OperationRequest {
            let __macro_local_4typefMu_: Foo.Type
            func run(
              isolation: isolated (any Actor)?,
              in context: OperationContext,
              with continuation: OperationContinuation<Int, Never>
            ) -> Int {
              __macro_local_4typefMu_.something()
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

          static func $something(arg: Int) -> SomethingOperation {
            SomethingOperation(arg: arg, __macro_local_4typefMu_: Self.self)
          }

          struct SomethingOperation: OperationRequest {
            let arg: Int
            let __macro_local_4typefMu_: Foo.Type
            func run(
              isolation: isolated (any Actor)?,
              in context: OperationContext,
              with continuation: OperationContinuation<Int, Never>
            ) -> Int {
              __macro_local_4typefMu_.something(arg: arg)
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

          func $something(arg: Int) -> SomethingOperation {
            SomethingOperation(arg: arg, __macro_local_4typefMu_: self)
          }

          struct SomethingOperation: OperationRequest {
            let arg: Int
            let __macro_local_4typefMu_: Foo
            func run(
              isolation: isolated (any Actor)?,
              in context: OperationContext,
              with continuation: OperationContinuation<Int, Never>
            ) -> Int {
              __macro_local_4typefMu_.something(arg: arg)
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

          func $something(arg: Int) -> SomethingOperation {
            SomethingOperation(arg: arg, __macro_local_4typefMu_: self)
          }

          struct SomethingOperation: OperationRequest {
            let arg: Int
            let __macro_local_4typefMu_: Foo
            func run(
              isolation: isolated (any Actor)?,
              in context: OperationContext,
              with continuation: OperationContinuation<Int, Never>
            ) -> Int {
              __macro_local_4typefMu_.something(arg: arg)
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

          func $something(arg: Int) -> SomethingOperation {
            SomethingOperation(arg: arg)
          }

          struct SomethingOperation: OperationRequest {
            let arg: Int
            func run(
              isolation: isolated (any Actor)?,
              in context: OperationContext,
              with continuation: OperationContinuation<Int, Never>
            ) -> Int {
              something(arg: arg)
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

            func $something(arg: Int) -> SomethingOperation {
              SomethingOperation(arg: arg, __macro_local_4typefMu_: self)
            }

            struct SomethingOperation: OperationRequest {
              let arg: Int
              let __macro_local_4typefMu_: Foo
              func run(
                isolation: isolated (any Actor)?,
                in context: OperationContext,
                with continuation: OperationContinuation<Int, Never>
              ) -> Int {
                __macro_local_4typefMu_.something(arg: arg)
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

        public func $something(arg: Int) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        public struct SomethingOperation: OperationRequest {
          let arg: Int
          public func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, Never>
          ) -> Int {
            something(arg: arg)
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

        private func $something(arg: Int) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        private struct SomethingOperation: OperationRequest {
          let arg: Int
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, Never>
          ) -> Int {
            something(arg: arg)
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

        fileprivate func $something(arg: Int) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        fileprivate struct SomethingOperation: OperationRequest {
          let arg: Int
          fileprivate func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, Never>
          ) -> Int {
            something(arg: arg)
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
        func $something(arg: Int) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        @available(iOS 13.0, *)
        struct SomethingOperation: OperationRequest {
          let arg: Int
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, Never>
          ) -> Int {
            something(arg: arg)
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
        func $something(arg: Int) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        @available(iOS 13.0, *)
        @available(tvOS 13.0, *)
        struct SomethingOperation: OperationRequest {
          let arg: Int
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, Never>
          ) -> Int {
            something(arg: arg)
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

        func $something(arg: Int,) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        struct SomethingOperation: OperationRequest {
          let arg: Int
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, any Error>
          ) throws -> Int {
            try something(arg: arg, context: context, continuation: continuation)
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

        func $something(arg: Int,) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        struct SomethingOperation: OperationRequest {
          let arg: Int
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, MyError>
          ) throws(MyError) -> Int {
            try something(arg: arg, context: context, continuation: continuation)
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

        func $something(arg: Int,) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        struct SomethingOperation: OperationRequest {
          let arg: Int
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, any Error>
          ) throws -> Int {
            try something(arg: arg, context: context, continuation: continuation)
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

        func $something(arg: Int,) -> SomethingOperation {
          SomethingOperation(arg: arg)
        }

        struct SomethingOperation: OperationRequest {
          let arg: Int
          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<Int, MyError>
          ) throws(MyError) -> Int {
            try something(arg: arg, context: context, continuation: continuation)
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

        func $something<T: Creatable>() -> SomethingOperation<T> {
          SomethingOperation<T>()
        }

        struct SomethingOperation<T: Creatable>: OperationRequest {

          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<T, Never>
          ) -> sending T {
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

        func $something<T: Creatable>() -> SomethingOperation<T> {
          SomethingOperation<T>()
        }

        struct SomethingOperation<T: Creatable>: OperationRequest {

          func run(
            isolation: isolated (any Actor)?,
            in context: OperationContext,
            with continuation: OperationContinuation<T, Never>
          ) -> T {
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
