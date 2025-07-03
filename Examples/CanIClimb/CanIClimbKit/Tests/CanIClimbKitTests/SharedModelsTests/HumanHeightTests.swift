import CanIClimbKit
import CustomDump
import Testing

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
