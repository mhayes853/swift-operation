import FoundationModels

// MARK: - Response

extension NumericHealthSamples.Response: ConvertibleToGeneratedContent {
  public var generatedContent: GeneratedContent {
    switch self {
    case .permissionDenied:
      GeneratedContent("Permission Denied")

    case .samples(let samples):
      samples.generatedContent
    }
  }
}

// MARK: - Samples

extension NumericHealthSamples: ConvertibleToGeneratedContent {
  public var generatedContent: GeneratedContent {
    GeneratedContent(
      properties: [
        "kind": self.kind.generableDescription,
        "sampleUnits": self.kind.sampleUnitsGenerableDescription,
        "startDate": self.elements.first?.timestamp.description ?? "N/A",
        "endDate": self.elements.last?.timestamp.description ?? "N/A",
        "samples": self.elements.map { sample in
          GeneratedContent(
            properties: ["timestamp": sample.timestamp.description, "value": sample.value]
          )
        }
      ]
    )
  }
}

// MARK: - Helpers

extension NumericHealthSamples.Kind {
  fileprivate var generableDescription: String {
    switch self {
    case .distanceWalkingRunningMeters: "Distance Walking/Running"
    case .stepCount: "Step Count"
    case .vo2Max: "VO2 Max"
    }
  }

  fileprivate var sampleUnitsGenerableDescription: String {
    switch self {
    case .distanceWalkingRunningMeters: "meters"
    case .stepCount: "steps"
    case .vo2Max: "ml/kg/min"
    }
  }
}
