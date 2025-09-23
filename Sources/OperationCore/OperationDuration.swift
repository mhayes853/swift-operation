// MARK: - OperationDuration

public struct OperationDuration: Hashable, Sendable {
  private var secondsComponent: Int64
  private var attosecondsComponent: Int64
}

// MARK: - Components

extension OperationDuration {
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
  public static func nanoseconds(_ value: some BinaryInteger) -> Self {
    let secs = Int64(value) / 1_000_000_000
    let attos = Int64(value % 1_000_000_000) * 1_000_000_000
    return Self(secondsComponent: secs, attosecondsComponent: attos)
  }

  public static func nanoseconds(_ value: some BinaryFloatingPoint) -> Self {
    let secs = Int64(value) / 1_000_000_000
    let attos = Int64(value.truncatingRemainder(dividingBy: 1_000_000_000) * 1_000_000_000)
    return Self(secondsComponent: secs, attosecondsComponent: attos)
  }

  public static func microseconds(_ value: some BinaryInteger) -> Self {
    let secs = Int64(value) / 1_000_000
    let attos = Int64(value % 1_000_000) * 1_000_000_000_000
    return Self(secondsComponent: secs, attosecondsComponent: attos)
  }

  public static func microseconds(_ value: some BinaryFloatingPoint) -> Self {
    let secs = Int64(value) / 1_000_000
    let attos = Int64(value.truncatingRemainder(dividingBy: 1_000_000) * 1_000_000_000_000)
    return Self(secondsComponent: secs, attosecondsComponent: attos)
  }

  public static func milliseconds(_ value: some BinaryInteger) -> Self {
    let secs = Int64(value) / 1000
    let attos = Int64(value) % 1000 * 1_000_000_000_000_000
    return Self(secondsComponent: secs, attosecondsComponent: attos)
  }

  public static func milliseconds(_ value: some BinaryFloatingPoint) -> Self {
    let secs = Int64(value) / 1000
    let attos = Int64(value.truncatingRemainder(dividingBy: 1000) * 1_000_000_000_000_000)
    return Self(secondsComponent: secs, attosecondsComponent: attos)
  }

  public static func seconds(_ value: some BinaryInteger) -> Self {
    Self(secondsComponent: Int64(value), attosecondsComponent: 0)
  }

  public static func seconds<F: BinaryFloatingPoint>(_ value: F) -> Self {
    let attos = Int64(value.truncatingRemainder(dividingBy: 1) * F(attosecondsPerSecond))
    return Self(secondsComponent: Int64(value), attosecondsComponent: attos)
  }
}

// MARK: - AdditiveArithmetic

extension OperationDuration: AdditiveArithmetic {
  public static let zero = Self(secondsComponent: 0, attosecondsComponent: 0)

  public static func + (lhs: Self, rhs: Self) -> Self {
    guard rhs >= .zero else { return lhs - -rhs }
    return Self.normalize(
      secs: lhs.secondsComponent &+ rhs.secondsComponent,
      attos: lhs.attosecondsComponent &+ rhs.attosecondsComponent
    )
  }

  public static func - (lhs: Self, rhs: Self) -> Self {
    guard rhs >= .zero else { return lhs + -rhs }
    return Self.normalize(
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
    return Self(secondsComponent: s, attosecondsComponent: a)
  }
}

extension OperationDuration {
  public static prefix func - (duration: Self) -> Self {
    Self(
      secondsComponent: -duration.secondsComponent,
      attosecondsComponent: -duration.attosecondsComponent
    )
  }
}

// MARK: - Duration Interop

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension OperationDuration {
  public init(duration: Duration) {
    let (secs, attos) = duration.components
    self.init(secondsComponent: secs, attosecondsComponent: attos)
  }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension Duration {
  public init(duration: OperationDuration) {
    let (secs, attos) = duration.components
    self.init(secondsComponent: secs, attosecondsComponent: attos)
  }
}

// MARK: - Constants

private let attosecondsPerSecond = Int64(1_000_000_000_000_000_000)
