import CanIClimbKit
import CustomDump
import Foundation
import Testing

@Suite("HumanModels tests")
struct HumanModelsTests {
  @Suite("HumanBMI tests")
  struct HumanBMITests {
    @Test(
      "Score",
      arguments: [
        (
          Measurement<UnitMass>(value: 150, unit: .pounds),
          HumanHeight.imperial(HumanHeight.Imperial(feet: 5, inches: 7)),
          23.3
        ),
        (
          Measurement<UnitMass>(value: 165, unit: .pounds),
          HumanHeight.imperial(HumanHeight.Imperial(feet: 5, inches: 10)),
          23.7
        ),
        (
          Measurement<UnitMass>(value: 200, unit: .pounds),
          HumanHeight.imperial(HumanHeight.Imperial(feet: 5, inches: 10)),
          28.7
        ),
        (
          Measurement<UnitMass>(value: 200, unit: .pounds),
          HumanHeight.imperial(HumanHeight.Imperial(feet: 6, inches: 10)),
          20.8
        ),
        (
          Measurement<UnitMass>(value: 120, unit: .pounds),
          HumanHeight.imperial(HumanHeight.Imperial(feet: 4, inches: 11)),
          24.2
        ),
        (
          Measurement<UnitMass>(value: 120, unit: .pounds),
          HumanHeight.imperial(HumanHeight.Imperial(feet: 3, inches: 0)),
          64.3
        )
      ]
    )
    func score(weight: Measurement<UnitMass>, height: HumanHeight, score: Double) {
      let bmi = HumanBMI(weight: weight, height: height)
      let range = (score - 0.1)...(score + 0.1)
      expectNoDifference(range.contains(bmi.score), true)
    }
  }

  @Suite("HumanHeight tests")
  struct HumanHeightTests {
    @Test("Converts To Imperial")
    func convertToImperial() {
      let height = HumanHeight.metric(HumanHeight.Metric(centimeters: 100))

      expectNoDifference(height.imperial, HumanHeight.Imperial(feet: 3, inches: 3))
    }

    @Test("Converts To Metric")
    func convertToMetric() {
      let height = HumanHeight.imperial(HumanHeight.Imperial(feet: 3, inches: 3))

      expectNoDifference(height.metric, HumanHeight.Metric(centimeters: 100))
    }
  }
}
