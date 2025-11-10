import MacroTesting
import OperationMacros
import Testing

@MainActor
@Suite(
  "ContextEntryMacro tests",
  .serialized,
  .macros(
    ["ContextEntry": ContextEntryMacro.self],
    record: .failed
  )
)
struct ContextEntryMacroTests {
  @Test("Basic Context Property")
  func basicContextProperty() {
    assertMacro {
      """
      extension OperationContext {
        @ContextEntry var property = "blob"
      }
      """
    } expansion: {
      """
      extension OperationContext {
        var property {
          get {
            self[__Key_property.self]
          }
          set {
            self[__Key_property.self] = newValue
          }
        }

        private struct __Key_property: OperationCore.OperationContext.Key {
          static let defaultValue = "blob"
        }
      }
      """
    }
  }

  @Test("Optional Context Property")
  func optionalContextProperty() {
    assertMacro {
      """
      extension OperationContext {
        @ContextEntry var property: String?
      }
      """
    } expansion: {
      """
      extension OperationContext {
        var property: String? {
          get {
            self[__Key_property.self]
          }
          set {
            self[__Key_property.self] = newValue
          }
        }

        private struct __Key_property: OperationCore.OperationContext.Key {
          static let defaultValue: String? = nil
        }
      }
      """
    }
    assertMacro {
      """
      extension OperationContext {
        @ContextEntry var property: Optional<String>
      }
      """
    } expansion: {
      """
      extension OperationContext {
        var property: Optional<String> {
          get {
            self[__Key_property.self]
          }
          set {
            self[__Key_property.self] = newValue
          }
        }

        private struct __Key_property: OperationCore.OperationContext.Key {
          static let defaultValue: Optional<String> = nil
        }
      }
      """
    }
    assertMacro {
      """
      extension OperationContext {
        @ContextEntry var property: String!
      }
      """
    } expansion: {
      """
      extension OperationContext {
        var property: String! {
          get {
            self[__Key_property.self]
          }
          set {
            self[__Key_property.self] = newValue
          }
        }

        private struct __Key_property: OperationCore.OperationContext.Key {
          static let defaultValue: String? = nil
        }
      }
      """
    }
  }

  @Test("Multiline Context Property")
  func multilineContextProperty() {
    assertMacro {
      """
      extension OperationContext {
        @ContextEntry var property = {
          var b = "blob"
          b = someTransform(b)
          return b.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
      }
      """
    } expansion: {
      """
      extension OperationContext {
        var property {
          get {
            self[__Key_property.self]
          }
          set {
            self[__Key_property.self] = newValue
          }
        }

        private struct __Key_property: OperationCore.OperationContext.Key {
          static let defaultValue = {
              var b = "blob"
              b = someTransform(b)
              return b.trimmingCharacters(in: .whitespacesAndNewlines)
            }()
        }
      }
      """
    }
  }

  @Test("Access Control Context Property")
  func accessControlContextProperty() {
    assertMacro {
      """
      extension OperationContext {
        @ContextEntry public var property = "blob"
      }
      """
    } expansion: {
      """
      extension OperationContext {
        public var property {
          get {
            self[__Key_property.self]
          }
          set {
            self[__Key_property.self] = newValue
          }
        }

        private struct __Key_property: OperationCore.OperationContext.Key {
          static let defaultValue = "blob"
        }
      }
      """
    }
  }

  @Test("Read-Only Context Property")
  func readOnlyControlContextProperty() {
    assertMacro {
      """
      extension OperationContext {
        @ContextEntry let property = "blob"
      }
      """
    } diagnostics: {
      """
      extension OperationContext {
        @ContextEntry let property = "blob"
        ┬────────────
        ╰─ 🛑 @ContextEntry can only be applied to a 'var' declaration.
      }
      """
    }
  }

  @Test("Private Context Property")
  func privateContextProperty() {
    assertMacro {
      """
      extension OperationContext {
        @ContextEntry private var property = "blob"
      }
      """
    } expansion: {
      """
      extension OperationContext {
        private var property {
          get {
            self[__Key_property.self]
          }
          set {
            self[__Key_property.self] = newValue
          }
        }

        private struct __Key_property: OperationCore.OperationContext.Key {
          static let defaultValue = "blob"
        }
      }
      """
    }
  }

  @Test("Explicitly Typed Context Property")
  func explicitlyTypedContextProperty() {
    assertMacro {
      """
      struct Foo {}

      extension OperationContext {
        @ContextEntry var property: Foo = .init()
      }
      """
    } expansion: {
      """
      struct Foo {}

      extension OperationContext {
        var property: Foo {
          get {
            self[__Key_property.self]
          }
          set {
            self[__Key_property.self] = newValue
          }
        }

        private struct __Key_property: OperationCore.OperationContext.Key {
          static let defaultValue: Foo = .init()
        }
      }
      """
    }
  }

  @Test("Global Actor Context Property")
  func globalActorContextProperty() {
    assertMacro {
      """
      extension OperationContext {
        @MainActor @ContextEntry var property = "blob"
      }
      """
    } expansion: {
      """
      extension OperationContext {
        @MainActor var property {
          get {
            self[__Key_property.self]
          }
          set {
            self[__Key_property.self] = newValue
          }
        }

        private struct __Key_property: OperationCore.OperationContext.Key {
          static let defaultValue = "blob"
        }
      }
      """
    }
  }

  @Test("Used Outside OperationContext Extension")
  func usedOutsideOperationContextExtension() {
    assertMacro {
      """
      struct Foo {
        @ContextEntry var property = "blob"
      }
      """
    } diagnostics: {
      """
      struct Foo {
        @ContextEntry var property = "blob"
        ┬────────────
        ╰─ 🛑 @ContextEntry can only be used inside an extension of OperationContext.
      }
      """
    }
  }

  @Test("Computed Context Property")
  func computedContextProperty() {
    assertMacro {
      """
      struct Foo {}

      extension OperationContext {
        @ContextEntry var property: Foo {
          Foo()
        }
      }
      """
    } diagnostics: {
      """
      struct Foo {}

      extension OperationContext {
        @ContextEntry var property: Foo {
        ┬────────────
        ╰─ 🛑 @ContextEntry can only be applied to a stored property.
          Foo()
        }
      }
      """
    }
  }

  @Test("No Default Value Context Property")
  func noDefaultValueContextProperty() {
    assertMacro {
      """
      struct Foo {}

      extension OperationContext {
        @ContextEntry var property: Foo
      }
      """
    } diagnostics: {
      """
      struct Foo {}

      extension OperationContext {
        @ContextEntry var property: Foo
        ┬────────────
        ╰─ 🛑 @ContextEntry requires a default value for a non-optional type.
      }
      """
    }
  }
}
