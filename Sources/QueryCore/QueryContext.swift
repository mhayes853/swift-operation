// MARK: - QueryContext

public struct QueryContext: Sendable {
  private var storage = Storage(entries: [:])

  public init() {}
}

// MARK: - Storage

extension QueryContext {
  private final class Storage: Sendable {
    struct Key: Hashable {
      let id: ObjectIdentifier
      let typeName: String

      init(type: Any.Type) {
        self.id = ObjectIdentifier(type)
        self.typeName = QueryCore.typeName(type)
      }
    }

    let entries: Lock<[Key: any Sendable]>

    init(entries: [Key: any Sendable]) {
      self.entries = Lock(entries)
    }
  }
}

// MARK: - QueryContextKey

extension QueryContext {
  public protocol Key<Value> {
    associatedtype Value: Sendable

    static var defaultValue: Value { get }
  }
}

// MARK: - Subscript

extension QueryContext {
  public subscript<Value>(_ key: (some Key<Value>).Type) -> Value {
    get {
      self.storage.entries.withLock { entries in
        let storageKey = Storage.Key(type: key)
        if let value = entries[storageKey] as? Value {
          return value
        }
        let defaultValue = key.defaultValue
        entries[storageKey] = defaultValue
        return defaultValue
      }
    }
    set {
      var storage: Storage
      defer { self.storage = storage }
      if !isKnownUniquelyReferenced(&self.storage) {
        storage = Storage(entries: self.storage.entries.withLock { $0 })
      } else {
        storage = self.storage
      }
      storage.entries.withLock { $0[Storage.Key(type: key)] = newValue }
    }
  }
}

// MARK: - CustomStringConvertible

extension QueryContext: CustomStringConvertible {
  public var description: String {
    self.storage.entries.withLock {
      let string = $0.map { (key, value) in "\(key.typeName) = \(value)" }.joined(separator: ", ")
      return "[\(string)]"
    }
  }
}
