import HealthKit

// MARK: - HKLoader

extension NumericHealthSamples {
  public final class HKLoader: Loader {
    private let healthStore: HKHealthStore
    public let kind: NumericHealthSamples.Kind

    public init(healthStore: HKHealthStore = .canIClimb, kind: NumericHealthSamples.Kind) {
      self.healthStore = healthStore
      self.kind = kind
    }

    public func samples(from request: Request) async throws -> Response {
      let status = self.healthStore.authorizationStatus(for: self.kind.quantityType)
      guard status == .sharingAuthorized else { return .permissionDenied }

      let predicate = HKQuery.predicateForSamples(
        withStart: request.interval.start,
        end: request.interval.end
      )
      let descriptor = HKSampleQueryDescriptor(
        predicates: [.quantitySample(type: self.kind.quantityType, predicate: predicate)],
        sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
      )
      let samples = NumericHealthSamples(
        kind: self.kind,
        elements: try await descriptor.result(for: self.healthStore)
          .map { sample in
            let value = sample.quantity.doubleValue(for: self.kind.unit)
            return NumericHealthSamples.Element(timestamp: sample.startDate, value: value)
          }
      )
      return .samples(samples)
    }
  }
}

// MARK: - Helpers

extension NumericHealthSamples.Kind {
  fileprivate var quantityType: HKQuantityType {
    switch self {
    case .distanceWalkingRunningMeters: .quantityType(forIdentifier: .distanceWalkingRunning)!
    case .stepCount: .quantityType(forIdentifier: .stepCount)!
    case .vo2Max: .quantityType(forIdentifier: .vo2Max)!
    }
  }

  fileprivate var unit: HKUnit {
    switch self {
    case .distanceWalkingRunningMeters: .meter()
    case .stepCount: .count()
    case .vo2Max:
      .liter().unitDivided(by: .gramUnit(with: .kilo)).unitDivided(by: .minute())
    }
  }
}
