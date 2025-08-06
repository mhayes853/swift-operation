import IdentifiedCollections
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

  @ObservationIgnored public var onDismissed: (() -> Void)?

  public var path = [Path]()

  public init() {
    @Dependency(ApplicationLaunch.ID.self) var launchId
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

  public func launchSelected(id: ApplicationLaunch.ID) async throws {
    try await self.$selectedLaunch.load(
      ApplicationLaunchRecord.find(#bind(id)),
      animation: .bouncy
    )
    try await self.$analyzes.load(GroupQueryAnalysisRequest(launchId: id), animation: .bouncy)
    self.path.removeLast()
  }

  public func dismissed() {
    self.onDismissed?()
  }
}

extension QueryDevToolsModel {
  @CasePathable
  public enum Path: Hashable, Sendable {
    case selectLaunch
    case analysisDetail(QueryAnalysis, ApplicationLaunch)
  }
}

// MARK: - QueryDevToolsView

public struct QueryDevToolsView: View {
  @Bindable private var model: QueryDevToolsModel

  public init(model: QueryDevToolsModel) {
    self.model = model
  }

  public var body: some View {
    NavigationStack(path: self.$model.path) {
      AnalyzesListView(model: self.model)
        .navigationTitle("Query Dev Tools")
        .navigationDestination(for: QueryDevToolsModel.Path.self) { path in
          switch path {
          case .selectLaunch:
            LaunchPickerView(model: self.model)
          case .analysisDetail(let analysis, let launch):
            QueryAnalysisView(analysis: analysis, launch: launch)
          }
        }
        .dismissable { self.model.dismissed() }
    }
  }
}

// MARK: - AnalyzesListView

private struct AnalyzesListView: View {
  let model: QueryDevToolsModel

  public var body: some View {
    List {
      if let launch = self.model.selectedLaunch {
        SelectedLaunchSectionView(launch: launch)
        ForEach(self.model.analyzes.elements, id: \.key) { element in
          AnalysisListSectionView(name: element.key, analyzes: element.value, launch: launch)
        }
      }
    }
  }
}

private struct SelectedLaunchSectionView: View {
  let launch: ApplicationLaunch

  var body: some View {
    Section {
      NavigationLink(value: QueryDevToolsModel.Path.selectLaunch) {
        LaunchLabelView(launch: self.launch)
      }
    } header: {
      Text("Viewing Launch")
    }
  }
}

private struct AnalysisListSectionView: View {
  let name: QueryAnalysis.QueryName
  let analyzes: IdentifiedArrayOf<QueryAnalysis>
  let launch: ApplicationLaunch

  var body: some View {
    Section {
      ForEach(self.analyzes) { analysis in
        NavigationLink(value: QueryDevToolsModel.Path.analysisDetail(analysis, self.launch)) {
          VStack(alignment: .leading) {
            Text(analysis.queryDataResult.dataDescription)
              .lineLimit(2)
              .font(.headline)
            if analysis.queryDataResult.didSucceed {
              Text("Success")
                .font(.caption)
                .foregroundColor(.green)
            } else {
              Text("Failed")
                .font(.caption)
                .foregroundColor(.red)
            }
          }
        }
      }
    } header: {
      Text(self.name.rawValue)
    }
  }
}

// MARK: - LaunchPickerView

private struct LaunchPickerView: View {
  let model: QueryDevToolsModel
  @FetchAll(ApplicationLaunchRecord.all.order(by: \.id)) private var launches

  public var body: some View {
    List {
      ForEach(self.launches) { launch in
        Button {
          Task { try await self.model.launchSelected(id: launch.id) }
        } label: {
          HStack {
            LaunchLabelView(launch: launch)
            Spacer()
            Image(systemName: "chevron.right")
              .foregroundColor(.secondary)
          }
        }
        .buttonStyle(.plain)
      }
    }
    .navigationTitle("Select Launch")
  }
}

// MARK: - QueryAnalysisView

private struct QueryAnalysisView: View {
  let analysis: QueryAnalysis
  let launch: ApplicationLaunch

  public var body: some View {
    Form {
      AnalysisLaunchSectionView(launch: self.launch)
      AnalysisSectionView(analysis: self.analysis)
      if !self.analysis.yieldedQueryDataResults.isEmpty {
        AnalysisYieldedResultsSectionView(results: self.analysis.yieldedQueryDataResults)
      }
    }
    .navigationTitle(self.analysis.queryName.rawValue)
  }
}

private struct AnalysisSectionView: View {
  let analysis: QueryAnalysis

  var body: some View {
    Section {
      HStack {
        Text("Path").font(.headline)
        Spacer()
        Text(self.analysis.queryPathDescription)
      }

      HStack {
        Text("Result")
          .font(.headline)
        Spacer()
        if analysis.queryDataResult.didSucceed {
          Text("Success")
            .foregroundColor(.green)
        } else {
          Text("Failed")
            .foregroundColor(.red)
        }
      }

      HStack {
        Text("Data").font(.headline)
        Spacer()
        Text(self.analysis.queryDataResult.dataDescription)
      }

      HStack {
        Text("Duration").font(.headline)
        Spacer()
        let time = Measurement<UnitDuration>(
          value: self.analysis.queryRuntimeDuration,
          unit: .seconds
        )
        Text(time.formatted())
      }

      HStack {
        Text("Retry Attempt").font(.headline)
        Spacer()
        Text("\(self.analysis.queryRetryAttempt)")
      }

      HStack {
        Text("Date").font(.headline)
        Spacer()
        Text(self.analysis.id.date, format: .iso8601)
      }

    } header: {
      Text("Query")
    }
  }
}

private struct AnalysisLaunchSectionView: View {
  let launch: ApplicationLaunch

  var body: some View {
    Section {
      LaunchLabelView(launch: self.launch)
    } header: {
      Text("Launch")
    }
  }
}

private struct AnalysisYieldedResultsSectionView: View {
  let results: [QueryAnalysis.DataResult]

  var body: some View {
    Section {
      ForEach(self.results.enumerated(), id: \.offset) { index, result in
        VStack(alignment: .leading) {
          Text(result.dataDescription)
          if result.didSucceed {
            Text("Success")
              .font(.caption)
              .foregroundColor(.green)
          } else {
            Text("Failed")
              .font(.caption)
              .foregroundColor(.red)
          }
        }
      }
    } header: {
      Text("Yielded Results")
    } footer: {
      Text(
        """
        Yielded results do not represent the final results of a query, but rather the intermediate \
        results yielded to the `QueryContinuation` before the final result was produced.
        """
      )
    }
  }
}

// MARK: - LaunchLabelView

private struct LaunchLabelView: View {
  let launch: ApplicationLaunch

  var body: some View {
    VStack(alignment: .leading) {
      Text("\(self.launch.id.date.formatted(.dateTime))")
        .font(.headline)
      Text(self.launch.localizedDeviceName)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

#Preview {
  @Previewable @State var isPresenting = true

  let _ = try! prepareDependencies {
    $0.defaultDatabase = try canIClimbDatabase()
    $0[ApplicationLaunch.ID.self] = QueryAnalysis.mock1.launchId

    var a2 = QueryAnalysisRecord.mock2
    a2.yieldedQueryDataResults = [
      QueryAnalysis.DataResult(didSucceed: true, dataDescription: "Value 1"),
      QueryAnalysis.DataResult(didSucceed: false, dataDescription: "Value 2")
    ]

    try $0.defaultDatabase.write { db in
      try db.seed {
        QueryAnalysisRecord.mock1
        a2

        ApplicationLaunchRecord(
          id: QueryAnalysis.mock1.launchId,
          localizedDeviceName: DeviceInfo.testValue.localizedModelName
        )
        ApplicationLaunchRecord(
          id: QueryAnalysis.mock2.launchId,
          localizedDeviceName: DeviceInfo.testValue.localizedModelName
        )
      }
    }
  }

  let model = QueryDevToolsModel()

  Button("Present") {
    isPresenting = true
  }
  .sheet(isPresented: $isPresenting) {
    QueryDevToolsView(model: model)
  }
}
