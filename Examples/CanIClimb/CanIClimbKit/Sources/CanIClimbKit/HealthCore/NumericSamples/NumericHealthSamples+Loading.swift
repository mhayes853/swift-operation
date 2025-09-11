import Foundation
import Operation
import RegexBuilder

// MARK: - Request

extension NumericHealthSamples {
  public struct Request: Hashable, Sendable {
    public let interval: DateInterval

    public init(interval: DateInterval) {
      self.interval = interval
    }
  }
}

extension NumericHealthSamples.Request {
  private static nonisolated(unsafe) let regex = Regex {
    "last"
    Optionally {
      OneOrMore(.whitespace)
      Capture {
        OneOrMore(.digit)
      }
    }
    OneOrMore(.whitespace)
    Capture {
      ChoiceOf {
        "day"
        "days"
        "week"
        "weeks"
        "month"
        "months"
      }
    }
  }

  public init(query: String, now: Date = .now, calendar: Calendar = .autoupdatingCurrent) {
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard let match = normalized.firstMatch(of: Self.regex) else {
      self.init(interval: DateInterval(start: now, end: now))
      return
    }

    let countStr = match.1
    let unitStr = match.2
    let count = Int(countStr ?? "1") ?? 1

    switch unitStr {
    case "day", "days":
      let duration = TimeInterval(60 * 60 * 24 * count)
      self.init(
        interval: DateInterval(start: now.addingTimeInterval(-duration), duration: duration)
      )

    case "week", "weeks":
      let duration = TimeInterval(60 * 60 * 24 * 7 * count)
      self.init(
        interval: DateInterval(start: now.addingTimeInterval(-duration), duration: duration)
      )

    case "month", "months":
      if let start = calendar.date(byAdding: .month, value: -count, to: now) {
        self.init(interval: DateInterval(start: start, end: now))
      } else {
        self.init(interval: DateInterval(start: now, end: now))
      }

    default:
      self.init(interval: DateInterval(start: now, end: now))
    }
  }
}

// MARK: - Loader

extension NumericHealthSamples {
  public protocol Loader: Sendable, Identifiable where ID: Sendable {
    func samples(from request: Request) async throws -> NumericHealthSamples
  }
}

// MARK: - Operation

extension NumericHealthSamples {
  public static func query(
    for request: Request,
    using loader: any Loader
  ) -> some QueryRequest<NumericHealthSamples, any Error> {
    Query(loader: loader, request: request)
  }

  public struct Query: QueryRequest {
    let loader: any Loader
    let request: Request

    public var path: OperationPath {
      ["numeric-health-samples", self.request, self.loader.id]
    }

    public func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<NumericHealthSamples, any Error>
    ) async throws -> NumericHealthSamples {
      try await self.loader.samples(from: self.request)
    }
  }
}
