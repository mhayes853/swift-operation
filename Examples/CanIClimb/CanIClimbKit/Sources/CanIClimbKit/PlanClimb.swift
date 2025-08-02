import Foundation
import Observation
import SharingQuery
import SwiftUI

// MARK: - PlanClimbModel

@MainActor
@Observable
public final class PlanClimbModel {
  @ObservationIgnored
  @SharedQuery<Mountain.Query.State> public var mountain: Mountain??

  public init(mountainId: Mountain.ID) {
    self._mountain = SharedQuery(Mountain.query(id: mountainId))
  }
}

// MARK: - PlanClimbView

public struct PlanClimbView: View {
  @Bindable private var model: PlanClimbModel

  public init(model: PlanClimbModel) {
    self.model = model
  }

  public var body: some View {
    Text("PlanClimbView")
  }
}
