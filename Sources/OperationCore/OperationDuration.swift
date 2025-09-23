import Foundation

// MARK: - OperationDuration

/// A precise duration type that's usable for delays.
///
/// If available, you should use Swift's built-in `Duration` instead. This type exists for
/// platforms where the built-in `Duration` is unavailable, and has a similar API to compensate.
public struct OperationDuration: Hashable, Sendable {
  private var secondsComponent: Int64
  private var attosecondsComponent: Int64

  private init(_secondsComponent: Int64, _attosecondsComponent: Int64) {
    self.secondsComponent = _secondsComponent
    self.attosecondsComponent = _attosecondsComponent
  }

  /// Construct a duration by adding attoseconds to a seconds value.
  ///
  /// This is useful for when an external decomposed components of a duration
  /// has been stored and needs to be reconstituted. Since the values are added
  /// no precondition is expressed for the attoseconds being limited to 1e18.
  ///
  ///       let d1 = OperationDuration(
  ///         secondsComponent: 3,
  ///         attosecondsComponent: 123000000000000000
  ///       )
  ///       print(d1) // 3.123 seconds
  ///
  ///       let d2 = OperationDuration(
  ///         secondsComponent: 3,
  ///         attosecondsComponent: -123000000000000000
  ///       )
  ///       print(d2) // 2.877 seconds
  ///
  ///       let d3 = OperationDuration(
  ///         secondsComponent: -3,
  ///         attosecondsComponent: -123000000000000000
  ///       )
  ///       print(d3) // -3.123 seconds
  ///
  /// - Parameters:
  ///   - secondsComponent: The seconds component portion of the duration value.
  ///   - attosecondsComponent: The attosecond component portion of the duration value.
  public init(secondsComponent: Int64, attosecondsComponent: Int64) {
    self.init(_secondsComponent: secondsComponent, _attosecondsComponent: 0)

    let attosDuration = Self(
      _secondsComponent: attosecondsComponent / attosecondsPerSecond,
      _attosecondsComponent: attosecondsComponent % attosecondsPerSecond
    )
    self += attosDuration
  }
}

// MARK: - Components

extension OperationDuration {
  /// The composite components of the duration.
  ///
  /// This is intended for facilitating conversions to existing time types. The
  /// attoseconds value will not exceed 1e18 or be lower than -1e18.
  public var components: (seconds: Int64, attoseconds: Int64) {
    (secondsComponent, attosecondsComponent)
  }
}

// MARK: - Comparability

extension OperationDuration: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.secondsComponent < rhs.secondsComponent
      || (lhs.secondsComponent == rhs.secondsComponent
        && lhs.attosecondsComponent < rhs.attosecondsComponent)
  }
}

// MARK: - Initializers

extension OperationDuration {
  /// Construct a duration given a number of nanoseconds represented as a `BinaryInteger`.
  ///
  ///       let d: OperationDuration = .nanoseconds(77)
  ///
  /// - Returns: A duration representing a given number of nanoseconds.
  public static func nanoseconds(_ value: some BinaryInteger) -> Self {
    let secs = Int64(value) / 1_000_000_000
    let attos = Int64(value % 1_000_000_000) * attosecondsPerNanosecond
    return Self(_secondsComponent: secs, _attosecondsComponent: attos)
  }

  /// Construct a duration given a number of nanoseconds represented as a `BinaryFloatingPoint`.
  ///
  ///       let d: OperationDuration = .nanoseconds(77.77)
  ///
  /// - Returns: A duration representing a given number of nanoseconds.
  public static func nanoseconds<F: BinaryFloatingPoint>(_ value: F) -> Self {
    let secs = Int64(value) / 1_000_000_000
    let attos = Int64(
      value.truncatingRemainder(dividingBy: 1_000_000_000) * F(attosecondsPerNanosecond)
    )
    return Self(_secondsComponent: secs, _attosecondsComponent: attos)
  }

  /// Construct a duration given a number of microseconds represented as a `BinaryInteger`.
  ///
  ///       let d: OperationDuration = .microseconds(77)
  ///
  /// - Returns: A duration representing a given number of microseconds.
  public static func microseconds(_ value: some BinaryInteger) -> Self {
    let secs = Int64(value) / 1_000_000
    let attos = Int64(value % 1_000_000) * attosecondsPerMicrosecond
    return Self(_secondsComponent: secs, _attosecondsComponent: attos)
  }

  /// Construct a duration given a number of microseconds represented as a `BinaryFloatingPoint`.
  ///
  ///       let d: OperationDuration = .microseconds(77.77)
  ///
  /// - Returns: A duration representing a given number of microseconds.
  public static func microseconds<F: BinaryFloatingPoint>(_ value: F) -> Self {
    let secs = Int64(value) / 1_000_000
    let attos = Int64(
      value.truncatingRemainder(dividingBy: 1_000_000) * F(attosecondsPerMicrosecond)
    )
    return Self(_secondsComponent: secs, _attosecondsComponent: attos)
  }

  /// Construct a duration given a number of milliseconds represented as a `BinaryInteger`.
  ///
  ///       let d: OperationDuration = .milliseconds(77)
  ///
  /// - Returns: A duration representing a given number of milliseconds.
  public static func milliseconds(_ value: some BinaryInteger) -> Self {
    let secs = Int64(value) / 1000
    let attos = Int64(value) % 1000 * attosecondsPerMillisecond
    return Self(_secondsComponent: secs, _attosecondsComponent: attos)
  }

  /// Construct a duration given a number of milliseconds represented as a `BinaryFloatingPoint`.
  ///
  ///       let d: OperationDuration = .milliseconds(77.77)
  ///
  /// - Returns: A duration representing a given number of milliseconds.
  public static func milliseconds<F: BinaryFloatingPoint>(_ value: F) -> Self {
    let secs = Int64(value) / 1000
    let attos = Int64(value.truncatingRemainder(dividingBy: 1000) * F(attosecondsPerMillisecond))
    return Self(_secondsComponent: secs, _attosecondsComponent: attos)
  }

  /// Construct a duration given a number of seconds represented as a `BinaryInteger`.
  ///
  ///       let d: OperationDuration = .seconds(77)
  ///
  /// - Returns: A duration representing a given number of seconds.
  public static func seconds(_ value: some BinaryInteger) -> Self {
    Self(_secondsComponent: Int64(value), _attosecondsComponent: 0)
  }

  /// Construct a duration given a number of seconds represented as a `BinaryFloatingPoint`.
  ///
  ///       let d: OperationDuration = .seconds(77.77)
  ///
  /// - Returns: A duration representing a given number of seconds.
  public static func seconds<F: BinaryFloatingPoint>(_ value: F) -> Self {
    let attos = Int64(value.truncatingRemainder(dividingBy: 1) * F(attosecondsPerSecond))
    return Self(_secondsComponent: Int64(value), _attosecondsComponent: attos)
  }
}

// MARK: - AdditiveArithmetic

extension OperationDuration: AdditiveArithmetic {
  public static let zero = Self(secondsComponent: 0, attosecondsComponent: 0)

  public static func + (lhs: Self, rhs: Self) -> Self {
    Self.normalize(
      secs: lhs.secondsComponent &+ rhs.secondsComponent,
      attos: lhs.attosecondsComponent &+ rhs.attosecondsComponent
    )
  }

  public static func - (lhs: Self, rhs: Self) -> Self {
    Self.normalize(
      secs: lhs.secondsComponent &- rhs.secondsComponent,
      attos: lhs.attosecondsComponent &- rhs.attosecondsComponent
    )
  }

  static func normalize(secs: Int64, attos: Int64) -> Self {
    var s = secs
    var a = attos
    if a <= -attosecondsPerSecond || a >= attosecondsPerSecond {
      let q = a / attosecondsPerSecond
      let r = a % attosecondsPerSecond
      s &+= q
      a = r
    }
    if s > 0 && a < 0 {
      s &-= 1
      a &+= attosecondsPerSecond
    } else if s < 0 && a > 0 {
      s &+= 1
      a &-= attosecondsPerSecond
    }
    return Self(_secondsComponent: s, _attosecondsComponent: a)
  }
}

// MARK: - Negation

extension OperationDuration {
  public static prefix func - (duration: Self) -> Self {
    Self(
      _secondsComponent: -duration.secondsComponent,
      _attosecondsComponent: -duration.attosecondsComponent
    )
  }
}

// MARK: - Multiplication

extension OperationDuration {
  public static func * (lhs: Self, rhs: Int) -> Self {
    .seconds(lhs.secondsDouble * Double(rhs))
  }

  public static func *= (lhs: inout Self, rhs: Int) {
    lhs = lhs * rhs
  }
}

// MARK: - Division

extension OperationDuration {
  public static func / (lhs: Self, rhs: Self) -> Double {
    lhs.secondsDouble / rhs.secondsDouble
  }

  public static func / (lhs: Self, rhs: Int) -> Self {
    .seconds(lhs.secondsDouble / Double(rhs))
  }

  public static func /= (lhs: inout Self, rhs: Int) {
    lhs = lhs / rhs
  }
}

// MARK: - CustomStringConvertible

extension OperationDuration: CustomStringConvertible {
  public var description: String {
    "\(self.secondsDouble) seconds"
  }
}

// MARK: - Seconds Double

extension OperationDuration {
  var secondsDouble: Double {
    Double(secondsComponent) + Double(attosecondsComponent) / Double(attosecondsPerSecond)
  }
}

// MARK: - Duration Interop

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension OperationDuration {
  /// Creates a duration from Swift's built-in `Duration` type.
  ///
  /// - Parameter duration: A `Duration`.
  public init(duration: Duration) {
    let (secs, attos) = duration.components
    self.init(_secondsComponent: secs, _attosecondsComponent: attos)
  }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension Duration {
  /// Creates a duration from an ``OperationDuration`` type.
  ///
  /// - Parameter duration: An ``OperationDuration``.
  public init(duration: OperationDuration) {
    let (secs, attos) = duration.components
    self.init(secondsComponent: secs, attosecondsComponent: attos)
  }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension OperationDuration: DurationProtocol {}

// MARK: - Attoseconds Interop

@available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
extension OperationDuration {
  /// Construct a duration from the given number of attoseconds.
  ///
  /// This directly constructs a `Duration` from the given number of attoseconds.
  ///
  ///     let d = Duration(attoseconds: 1_000_000_000_000_000_000)
  ///     print(d) // 1.0 seconds
  ///
  /// - Parameter attoseconds: The total duration expressed in attoseconds.
  public init(attoseconds: Int128) {
    let seconds = Int64(attoseconds / Int128(attosecondsPerSecond))
    let attos = Int64(attoseconds % Int128(attosecondsPerSecond))
    self.init(_secondsComponent: seconds, _attosecondsComponent: attos)
  }

  /// The number of attoseconds represented by this duration.
  ///
  /// This property provides direct access to the underlying number of attoseconds
  /// that the current duration represents.
  ///
  ///     let d = OperationDuration.seconds(1)
  ///     print(d.attoseconds) // 1_000_000_000_000_000_000
  public var attoseconds: Int128 {
    let attos = Int128(self.secondsComponent) * Int128(attosecondsPerSecond)
    return attos + Int128(self.attosecondsComponent)
  }
}

// MARK: - Random

extension OperationDuration {
  /// Generates a random duration in the specified `range`.
  ///
  /// - Parameter range: The range to generate in.
  /// - Returns: A random duration in `range`.
  public static func random(in range: Range<Self>) -> Self {
    var generator = SystemRandomNumberGenerator()
    return .random(in: range, using: &generator)
  }

  /// Generates a random duration in the specified `range`.
  ///
  /// - Parameters:
  ///   - range: The range to generate in.
  ///   - generator: The `RandomNumberGenerator` to use.
  /// - Returns: A random duration in `range`.
  public static func random(
    in range: Range<Self>,
    using generator: inout some RandomNumberGenerator
  ) -> Self {
    let secs = Int64.random(
      in: range.lowerBound.secondsComponent..<range.upperBound.secondsComponent,
      using: &generator
    )
    var attos = Int64.random(in: 0..<attosecondsPerSecond, using: &generator)
    if secs <= range.lowerBound.secondsComponent || secs >= range.upperBound.secondsComponent {
      let next = attos.clamped(
        in: range.lowerBound.attosecondsComponent..<range.upperBound.attosecondsComponent
      )
      attos = next ?? 0
    }
    return Self(_secondsComponent: secs, _attosecondsComponent: attos)
  }
}

// MARK: - Constants

private let attosecondsPerSecond = Int64(1_000_000_000_000_000_000)
private let attosecondsPerMillisecond = Int64(1_000_000_000_000_000)
private let attosecondsPerMicrosecond = Int64(1_000_000_000_000)
private let attosecondsPerNanosecond = Int64(1_000_000_000)
