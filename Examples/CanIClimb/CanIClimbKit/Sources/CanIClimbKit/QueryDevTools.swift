import Observation
import SharingGRDB
import SwiftUI
import SwiftUINavigation

// MARK: - QueryDevToolsModel

@MainActor
@Observable
public final class QueryDevToolsModel: HashableObject, Identifiable {
  @ObservationIgnored
  @Fetch public var analyzes: GroupQueryAnalysisRequest.Value

  @ObservationIgnored
  @FetchOne public var selectedLaunch: ApplicationLaunchRecord?

  public var path = [Path]()

  public init() {
    @Dependency(ApplicationLaunchID.self) var launchId
    self._analyzes = Fetch(
      wrappedValue: GroupQueryAnalysisRequest.Value(),
      GroupQueryAnalysisRequest(launchId: launchId),
      animation: .bouncy
    )
    self._selectedLaunch = FetchOne(
      wrappedValue: nil,
      ApplicationLaunchRecord.find(#bind(launchId))
    )
  }
}

extension QueryDevToolsModel {
  public func launchSelected(id: ApplicationLaunchID) async throws {
    try await self.$selectedLaunch.load(ApplicationLaunchRecord.find(#bind(id)))
    try await self.$analyzes.load(GroupQueryAnalysisRequest(launchId: id), animation: .bouncy)
  }
}

extension QueryDevToolsModel {
  @CasePathable
  public enum Path: Hashable, Sendable {
    case selectLaunch
    case analysisDetail(QueryAnalysis)
  }
}

// MARK: - QueryDevToolsView

public struct QueryDevToolsView: View {
  @Bindable var model: QueryDevToolsModel

  public var body: some View {
    NavigationStack(path: self.$model.path) {
      AnalyzesListView(analyzes: self.model.analyzes)
        .navigationTitle("Query Dev Tools")
        .navigationDestination(for: QueryDevToolsModel.Path.self) { path in
          switch path {
          case .selectLaunch:
            LaunchPickerView(model: self.model)
          case .analysisDetail(let analysis):
            QueryAnalysisView(analysis: analysis)
          }
        }
    }
  }
}

// MARK: - AnalyzesListView

private struct AnalyzesListView: View {
  let analyzes: GroupQueryAnalysisRequest.Value

  public var body: some View {
    List {

    }
  }
}

// MARK: - LauncPickerView

private struct LaunchPickerView: View {
  let model: QueryDevToolsModel

  public var body: some View {
    Text("TODO")
  }
}

// MARK: - QueryAnalysisView

private struct QueryAnalysisView: View {
  let analysis: QueryAnalysis

  public var body: some View {
    Text("TODO")
  }
}
