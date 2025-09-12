import Logging

extension Logger.MetadataValue {
  public enum CodableRepresentation: Hashable, Sendable, Codable {
    case string(String)
    indirect case dict([String: Self])
    indirect case array([Self])
  }
}

extension Logger.MetadataValue {
  public var codableRepresentation: CodableRepresentation {
    switch self {
    case .string(let string): .string(string)
    case .stringConvertible(let convertible): .string(convertible.description)
    case .dictionary(let metadata): .dict(metadata.mapValues(\.codableRepresentation))
    case .array(let array): .array(array.map(\.codableRepresentation))
    }
  }

  public init(codableRepresentation: CodableRepresentation) {
    switch codableRepresentation {
    case .string(let string):
      self = .string(string)
    case .dict(let dictionary):
      self = .dictionary(dictionary.mapValues { Self(codableRepresentation: $0) })
    case .array(let array):
      self = .array(array.map { Self(codableRepresentation: $0) })
    }
  }
}
