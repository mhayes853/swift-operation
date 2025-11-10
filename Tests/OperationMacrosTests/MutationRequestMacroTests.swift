import MacroTesting
import OperationMacros
import Testing

extension BaseTestSuite {
  @Suite("MutationRequestMacro tests")
  struct MutationRequestMacroTests {
    @Test("Basic Mutation")
    func basicMutation() {
      assertMacro {
        """
        @MutationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void

          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something()
          }
        }
        """
      }
    }

    @Test("Void Mutation")
    func voidMutation() {
      assertMacro {
        """
        @MutationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void

          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Void, Never>
          ) async  {
            something()
          }
        }
        """
      }
    }

    @Test("Mutation With Arguments")
    func mutationWithArguments() {
      assertMacro {
        """
        struct Args: Sendable {
          let arg: Int
          let arg2: String
        }

        @MutationRequest
        func something(arguments: Args) -> Int {
          arguments.arg2.count + arguments.arg
        }
        """
      } expansion: {
        """
        struct Args: Sendable {
          let arg: Int
          let arg2: String
        }
        func something(arguments: Args) -> Int {
          arguments.arg2.count + arguments.arg
        }

        nonisolated var $something: __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_()
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Args

          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arguments: arguments)
          }
        }
        """
      }
    }

    @Test("Mutation With Constructable Arguments")
    func mutationWithConstructableArguments() {
      assertMacro {
        """
        @MutationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          let arg2: String
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg, with: self.arg2)
          }
        }
        """
      }
    }

    @Test("Mutation With Duplicate Constructable Arguments")
    func mutationWithDuplicateConstructableArguments() {
      assertMacro {
        """
        @MutationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          let arg2: String
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(with: self.arg, with: self.arg2)
          }
        }
        """
      }
    }

    @Test("Mutation With Default Arguments")
    func mutationWithDefaultArguments() {
      assertMacro {
        """
        @MutationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg)
          }
        }
        """
      }
    }

    @Test("Mutation With Variadic Arguments")
    func mutationWithVariadicArguments() {
      assertMacro {
        """
        @MutationRequest
        func something(args: Int...) -> Int {
          args.reduce(0, +)
        }
        """
      } diagnostics: {
        """
        @MutationRequest
        func something(args: Int...) -> Int {
                       ┬───────────
                       ╰─ 🛑 Variadic arguments are not supported.
          args.reduce(0, +)
        }
        """
      }
    }

    @Test("Mutation With Inout Argument")
    func mutationWithInoutArgument() {
      assertMacro {
        """
        @MutationRequest
        func something(arg: inout Int) -> Int {
          arg += 1
          return arg
        }
        """
      } diagnostics: {
        """
        @MutationRequest
        func something(arg: inout Int) -> Int {
                       ┬─────────────
                       ╰─ 🛑 Inout arguments are not supported.
          arg += 1
          return arg
        }
        """
      }
    }

    @Test("Mutation With Context")
    func mutationWithContext() {
      assertMacro {
        """
        @MutationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg, context: context)
          }
        }
        """
      }
    }

    @Test("Mutation With Context And Continuation")
    func mutationWithContextAndContinuation() {
      assertMacro {
        """
        @MutationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Mutation With Context, Continuation, And Isolation")
    func mutationWithContextAndContinuationAndIsolation() {
      assertMacro {
        """
        @MutationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg, isolation: isolation, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Mutation With Only Reserved Arguments")
    func mutationWithOnlyReservedArguments() {
      assertMacro {
        """
        @MutationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void

          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(isolation: isolation, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Static Mutation")
    func staticMutation() {
      assertMacro {
        """
        struct Foo {
          @MutationRequest
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
            __macro_local_9somethingfMu_(arg: arg, __macro_local_4typefMu_: Self.self)
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
            typealias Arguments = Void
            let arg: Int
            let __macro_local_4typefMu_: Foo.Type
            var path: OperationCore.OperationPath {
            OperationCore.OperationPath(self)
            }
            func mutate(
              isolation: isolated (any Actor)?,
              with arguments: Arguments,
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

    @Test("Metatype Mutation")
    func metatypeMutation() {
      assertMacro {
        """
        struct Foo {
          static let value = 42

          @MutationRequest
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
            __macro_local_9somethingfMu_(__macro_local_4typefMu_: Self.self)
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
            typealias Arguments = Void
            let __macro_local_4typefMu_: Foo.Type
            var path: OperationCore.OperationPath {
            OperationCore.OperationPath(self)
            }
            func mutate(
              isolation: isolated (any Actor)?,
              with arguments: Arguments,
              in context: OperationCore.OperationContext,
              with continuation: OperationCore.OperationContinuation<Int, Never>
            ) async -> Int {
              __macro_local_4typefMu_.something()
            }
          }
        }
        """
      }
    }

    @Test("Extension Metatype Mutation")
    func extensionMetatypeMutation() {
      assertMacro {
        """
        struct Foo {
        }

        extension Foo {
          @MutationRequest
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
            __macro_local_9somethingfMu_(arg: arg, __macro_local_4typefMu_: Self.self)
          }

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
            typealias Arguments = Void
            let arg: Int
            let __macro_local_4typefMu_: Foo.Type
            var path: OperationCore.OperationPath {
            OperationCore.OperationPath(self)
            }
            func mutate(
              isolation: isolated (any Actor)?,
              with arguments: Arguments,
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

    @Test("Member Mutation")
    func memberMutation() {
      assertMacro {
        """
        struct Foo {
          let value: Int

          @MutationRequest
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

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
            typealias Arguments = Void
            let arg: Int
            let __macro_local_4typefMu_: Foo
            var path: OperationCore.OperationPath {
            OperationCore.OperationPath(self)
            }
            func mutate(
              isolation: isolated (any Actor)?,
              with arguments: Arguments,
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

    @Test("Extension Member Mutation")
    func extensionMemberMutation() {
      assertMacro {
        """
        struct Foo {
          let value: Int
        }

        extension Foo {
          @MutationRequest
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

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
            typealias Arguments = Void
            let arg: Int
            let __macro_local_4typefMu_: Foo
            var path: OperationCore.OperationPath {
            OperationCore.OperationPath(self)
            }
            func mutate(
              isolation: isolated (any Actor)?,
              with arguments: Arguments,
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

    @Test("Nested Function Mutation")
    func nestedFunctionMutation() {
      assertMacro {
        """
        func foo() {
          @MutationRequest
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

          nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
            typealias Arguments = Void
            let arg: Int
            var path: OperationCore.OperationPath {
            OperationCore.OperationPath(self)
            }
            func mutate(
              isolation: isolated (any Actor)?,
              with arguments: Arguments,
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

    @Test("Nested Function In Type Mutation")
    func nestedFunctionInTypeMutation() {
      assertMacro {
        """
        struct Foo {
          func foo() {
            @MutationRequest
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

            nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
              typealias Arguments = Void
              let arg: Int
              let __macro_local_4typefMu_: Foo
              var path: OperationCore.OperationPath {
              OperationCore.OperationPath(self)
              }
              func mutate(
                isolation: isolated (any Actor)?,
                with arguments: Arguments,
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

    @Test("Access Control Mutation")
    func accessControlMutation() {
      assertMacro {
        """
        @MutationRequest
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

        public nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          public typealias Arguments = Void
          let arg: Int
          public var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          public func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
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
        @MutationRequest
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

        private nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
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
        @MutationRequest
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

        fileprivate nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          fileprivate typealias Arguments = Void
          let arg: Int
          fileprivate var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          fileprivate func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg)
          }
        }
        """
      }
    }

    @Test("Availability Mutation")
    func availabilityMutation() {
      assertMacro {
        """
        @MutationRequest
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
        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
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
        @MutationRequest
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
        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg)
          }
        }
        """
      }
    }

    @Test("Throwing Mutation")
    func throwingMutation() {
      assertMacro {
        """
        @MutationRequest
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, any Error>
          ) async throws -> Int {
            try something(arg: self.arg, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Typed-Throwing Mutation")
    func typedThrowingMutation() {
      assertMacro {
        """
        struct MyError: Error {}

        @MutationRequest
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, MyError>
        ) throws(MyError) -> Int {
          arg
        }
        """
      } diagnostics: {
        """

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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, MyError>
          ) async throws(MyError) -> Int {
            try something(arg: self.arg, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Async Throwing Mutation")
    func asyncThrowingMutation() {
      assertMacro {
        """
        @MutationRequest
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, any Error>
        ) async throws -> Int {
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
        ) async throws -> Int {
          arg
        }

        nonisolated func $something(arg: Int,) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, any Error>
          ) async throws -> Int {
            try await something(arg: self.arg, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Async Typed-Throws Mutation")
    func asyncTypedThrowsMutation() {
      assertMacro {
        """
        struct MyError: Error {}

        @MutationRequest
        func something(
          arg: Int,
          context: OperationContext,
          continuation: OperationContinuation<Int, MyError>
        ) async throws(MyError) -> Int {
          arg
        }
        """
      } diagnostics: {
        """

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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, MyError>
          ) async throws(MyError) -> Int {
            try await something(arg: self.arg, context: context, continuation: continuation)
          }
        }
        """
      }
    }

    @Test("Generic Mutation")
    func genericMutation() {
      assertMacro {
        """
        @MutationRequest
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

        nonisolated struct __macro_local_9somethingfMu_<T: Creatable>: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void

          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
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
        @MutationRequest
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

        nonisolated struct __macro_local_9somethingfMu_<T: Creatable>: OperationCore.MutationRequest, Hashable {
          typealias Arguments = Void

          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
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
        @MutationRequest
        struct Foo {
        }
        """
      } diagnostics: {
        """
        @MutationRequest
        ╰─ 🛑 @OperationRequest can only be applied to functions.
        struct Foo {
        }
        """
      }
    }

    @Test("Mutation With Invalid Isolation Parameter")
    func mutationWithInvalidIsolationParameter() {
      assertMacro {
        """
        @MutationRequest
        func something(isolation: Int) -> Int {
          arg
        }
        """
      } diagnostics: {
        """
        @MutationRequest
        func something(isolation: Int) -> Int {
                       ┬─────────────
                       ╰─ 🛑 'isolation' argument must be 'isolated (any Actor)?'.
          arg
        }
        """
      }
    }

    @Test("Mutation With Invalid Context Parameter")
    func mutationWithInvalidContextParameter() {
      assertMacro {
        """
        @MutationRequest
        func something(context: Int) -> Int {
          arg
        }
        """
      } diagnostics: {
        """
        @MutationRequest
        func something(context: Int) -> Int {
                       ┬───────────
                       ╰─ 🛑 'context' argument must be of type 'OperationContext'.
          arg
        }
        """
      }
    }

    @Test("Mutation With Invalid Continuation Parameter")
    func mutationWithInvalidContinuationParameter() {
      assertMacro {
        """
        @MutationRequest
        func something(continuation: Int) -> Int {
          arg
        }
        """
      } diagnostics: {
        """
        @MutationRequest
        func something(continuation: Int) -> Int {
                       ┬────────────────
                       ╰─ 🛑 'continuation' argument must be of type 'OperationContinuation<Int, Never>'
          arg
        }
        """
      }
    }

    @Test("Mutation With Path Inferred From ID")
    func mutationWithPathInferredFromID() {
      assertMacro {
        """
        @MutationRequest(path: .inferredFromIdentifiable)
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest, Identifiable {
          typealias Arguments = Void
          let id: Int
          var path: OperationCore.OperationPath {
          OperationCore.OperationPath(id)
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(id: self.id)
          }
        }
        """
      }
    }

    @Test("Mutation With Path Inferred From ID, No ID Argument")
    func mutationWithPathInferredFromIDNoIDArgument() {
      assertMacro {
        """
        @MutationRequest(path: .inferredFromIdentifiable)
        func something(arg: Int) -> Int {
          arg
        }
        """
      } diagnostics: {
        """
        @MutationRequest(path: .inferredFromIdentifiable)
        ╰─ 🛑 An 'id' argument is required when using '.inferredFromIdentifiable'
        func something(arg: Int) -> Int {
          arg
        }
        """
      }
    }

    @Test("Mutation With Custom Path Synthesis")
    func mutationWithCustomPathSynthesis() {
      assertMacro {
        """
        @MutationRequest(path: .custom { OperationPath("blob") })
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest {
          typealias Arguments = Void

          var path: OperationCore.OperationPath {
          makePath()
          }
          private func makePath() -> OperationCore.OperationPath {
            OperationPath("blob")
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
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
        @MutationRequest(
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest {
          typealias Arguments = Void

          var path: OperationCore.OperationPath {
          makePath()
          }
          private func makePath() -> OperationCore.OperationPath {

              OperationPath("blob")
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
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
        @MutationRequest(path: .custom { (arg: Int) in ["blob", arg] })
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          makePath(arg: arg)
          }
          private func makePath(arg: Int) -> OperationCore.OperationPath {
            ["blob", arg]
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
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
        @MutationRequest(path: .custom { (arg: Int) in ["blob", arg] })
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest {
          typealias Arguments = Void
          let arg: Int
          var path: OperationCore.OperationPath {
          makePath(arg: arg)
          }
          private func makePath(arg: Int) -> OperationCore.OperationPath {
            ["blob", arg]
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
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
        struct Args: Sendable {}

        @MutationRequest(path: .custom { (arg: Int) in ["blob", arg] })
        func something(arg: Int, arguments: Args) -> Int {
          arg
        }
        """
      } expansion: {
        """
        struct Args: Sendable {}
        func something(arg: Int, arguments: Args) -> Int {
          arg
        }

        nonisolated func $something(arg: Int,) -> __macro_local_9somethingfMu_ {
          __macro_local_9somethingfMu_(arg: arg)
        }

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest {
          typealias Arguments = Args
          let arg: Int
          var path: OperationCore.OperationPath {
          makePath(arg: arg)
          }
          private func makePath(arg: Int) -> OperationCore.OperationPath {
            ["blob", arg]
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg, arguments: arguments)
          }
        }
        """
      }
      assertMacro {
        """
        @MutationRequest(path: .custom { (arg: Int, arg2: String) in ["blob", arg, arg2] })
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

        nonisolated struct __macro_local_9somethingfMu_: OperationCore.MutationRequest {
          typealias Arguments = Void
          let arg: Int
          let arg2: String
          var path: OperationCore.OperationPath {
          makePath(arg: arg, arg2: arg2)
          }
          private func makePath(arg: Int, arg2: String) -> OperationCore.OperationPath {
            ["blob", arg, arg2]
          }
          func mutate(
            isolation: isolated (any Actor)?,
            with arguments: Arguments,
            in context: OperationCore.OperationContext,
            with continuation: OperationCore.OperationContinuation<Int, Never>
          ) async -> Int {
            something(arg: self.arg, arg2: self.arg2)
          }
        }
        """
      }
    }

    @Test("Mutation With Custom Path Synthesis, Invalid Arguments")
    func mutationWithCustomPathSynthesisInvalidArguments() {
      assertMacro {
        """
        @MutationRequest(path: .custom { OperationPath("blob") })
        func something(arg: Int) -> Int {
          42
        }
        """
      } diagnostics: {
        """
        @MutationRequest(path: .custom { OperationPath("blob") })
                                       ┬────────────────────────
                                       ╰─ 🛑 Custom path closure must have arguments '(arg: Int)'
        func something(arg: Int) -> Int {
          42
        }
        """
      }
      assertMacro {
        """
        @MutationRequest(path: .custom { (arg: String) in OperationPath(arg) })
        func something(arg: Int) -> Int {
          42
        }
        """
      } diagnostics: {
        """
        @MutationRequest(path: .custom { (arg: String) in OperationPath(arg) })
                                       ┬──────────────────────────────────────
                                       ╰─ 🛑 Custom path closure must have arguments '(arg: Int)'
        func something(arg: Int) -> Int {
          42
        }
        """
      }
      assertMacro {
        """
        @MutationRequest(path: .custom { (arg: String, arg2: Int) in [arg, arg2] })
        func something(arg: Int) -> Int {
          42
        }
        """
      } diagnostics: {
        """
        @MutationRequest(path: .custom { (arg: String, arg2: Int) in [arg, arg2] })
                                       ┬──────────────────────────────────────────
                                       ╰─ 🛑 Custom path closure must have arguments '(arg: Int)'
        func something(arg: Int) -> Int {
          42
        }
        """
      }
      assertMacro {
        """
        @MutationRequest(path: .custom { (arg1: Int) in [arg] })
        func something(arg: Int) -> Int {
          42
        }
        """
      } diagnostics: {
        """
        @MutationRequest(path: .custom { (arg1: Int) in [arg] })
                                       ┬───────────────────────
                                       ╰─ 🛑 Custom path closure must have arguments '(arg: Int)'
        func something(arg: Int) -> Int {
          42
        }
        """
      }
      assertMacro {
        """
        @MutationRequest(path: .custom { (arg: Int) in [arg] })
        func something(arg: Int, arg2: String) -> Int {
          42
        }
        """
      } diagnostics: {
        """
        @MutationRequest(path: .custom { (arg: Int) in [arg] })
                                       ┬──────────────────────
                                       ╰─ 🛑 Custom path closure must have arguments '(arg: Int, arg2: String)'
        func something(arg: Int, arg2: String) -> Int {
          42
        }
        """
      }
    }
  }
}
