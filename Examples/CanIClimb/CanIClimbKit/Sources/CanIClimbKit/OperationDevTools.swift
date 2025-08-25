import IdentifiedCollections
import Observation
import SharingGRDB
import SwiftUI
import SwiftUINavigation

// MARK: - OperationDevToolsModel

@MainActor
@Observable
public final class OperationDevToolsModel: HashableObject, Identifiable {
  @ObservationIgnored
  @Fetch public var analyzes: GroupOperationAnalysisRequest.Value

  @ObservationIgnored
  @FetchOne public var selectedLaunch: ApplicationLaunchRecord?

  @ObservationIgnored public var onDismissed: (() -> Void)?

  public var path = [Path]()

  public init() {
    @Dependency(ApplicationLaunch.ID.self) var launchId
    self._analyzes = Fetch(
      wrappedValue: GroupOperationAnalysisRequest.Value(),
      GroupOperationAnalysisRequest(launchId: launchId),
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
    try await self.$analyzes.load(GroupOperationAnalysisRequest(launchId: id), animation: .bouncy)
    self.path.removeLast()
  }

  public func dismissed() {
    self.onDismissed?()
  }
}

extension OperationDevToolsModel {
  @CasePathable
  public enum Path: Hashable, Sendable {
    case selectLaunch
    case analysisDetail(OperationAnalysis, ApplicationLaunch)
  }
}

// MARK: - OperationDevToolsView

public struct OperationDevToolsView: View {
  @Bindable private var model: OperationDevToolsModel

  public init(model: OperationDevToolsModel) {
    self.model = model
  }

  public var body: some View {
    NavigationStack(path: self.$model.path) {
      AnalyzesListView(model: self.model)
        .navigationTitle("Operation Dev Tools")
        .navigationDestination(for: OperationDevToolsModel.Path.self) { path in
          switch path {
          case .selectLaunch:
            LaunchPickerView(model: self.model)
          case .analysisDetail(let analysis, let launch):
            OperationAnalysisView(analysis: analysis, launch: launch)
          }
        }
        .dismissable { self.model.dismissed() }
    }
  }
}

// MARK: - AnalyzesListView

private struct AnalyzesListView: View {
  let model: OperationDevToolsModel

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
      NavigationLink(value: OperationDevToolsModel.Path.selectLaunch) {
        LaunchLabelView(launch: self.launch)
      }
    } header: {
      Text("Viewing Launch")
    }
  }
}

private struct AnalysisListSectionView: View {
  let name: OperationAnalysis.OperationName
  let analyzes: IdentifiedArrayOf<OperationAnalysis>
  let launch: ApplicationLaunch

  var body: some View {
    Section {
      ForEach(self.analyzes) { analysis in
        NavigationLink(value: OperationDevToolsModel.Path.analysisDetail(analysis, self.launch)) {
          VStack(alignment: .leading) {
            Text(analysis.operationDataResult.dataDescription)
              .lineLimit(2)
              .font(.headline)
            if analysis.operationDataResult.didSucceed {
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
  let model: OperationDevToolsModel
  @FetchAll(ApplicationLaunchRecord.all.order(by: \.id)) private var launches

  public var body: some View {
    List {
      ForEach(self.launches) { launch in
        Button {
          Task { try await self.model.launchSelected(id: launch.id) }
        } label: {
          HStack {
            LaunchLabelView(launch: launch)
            TappableSpacer()
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

// MARK: - OperationAnalysisView

private struct OperationAnalysisView: View {
  let analysis: OperationAnalysis
  let launch: ApplicationLaunch

  public var body: some View {
    Form {
      AnalysisLaunchSectionView(launch: self.launch)
      AnalysisSectionView(analysis: self.analysis)
      if !self.analysis.yieldedOperationDataResults.isEmpty {
        AnalysisYieldedResultsSectionView(results: self.analysis.yieldedOperationDataResults)
      }
    }
    .navigationTitle(self.analysis.operationName.rawValue)
  }
}

private struct AnalysisSectionView: View {
  let analysis: OperationAnalysis

  var body: some View {
    Section {
      HStack {
        Text("Path").font(.headline)
        Spacer()
        Text(self.analysis.operationPathDescription)
      }

      HStack {
        Text("Result")
          .font(.headline)
        Spacer()
        if analysis.operationDataResult.didSucceed {
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
        Text(self.analysis.operationDataResult.dataDescription)
      }

      HStack {
        Text("Duration").font(.headline)
        Spacer()
        let time = Measurement<UnitDuration>(
          value: self.analysis.operationRuntimeDuration,
          unit: .seconds
        )
        Text(time.formatted())
      }

      HStack {
        Text("Retry Attempt").font(.headline)
        Spacer()
        Text("\(self.analysis.operationRetryAttempt)")
      }

      HStack {
        Text("Date").font(.headline)
        Spacer()
        Text(self.analysis.id.date, format: .iso8601)
      }

    } header: {
      Text("Operation")
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
  let results: [OperationAnalysis.DataResult]

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
        Yielded results do not represent the final results of an operation, but rather the intermediate \
        results yielded to the `OperationContinuation` before the final result was produced.
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
    $0[ApplicationLaunch.ID.self] = OperationAnalysis.mock1.launchId

    var a2 = OperationAnalysisRecord.mock2
    a2.yieldedOperationDataResults = [
      OperationAnalysis.DataResult(didSucceed: true, dataDescription: "Value 1"),
      OperationAnalysis.DataResult(didSucceed: false, dataDescription: "Value 2")
    ]

    try $0.defaultDatabase.write { db in
      try db.seed {
        OperationAnalysisRecord.mock1
        a2

        ApplicationLaunchRecord(
          id: OperationAnalysis.mock1.launchId,
          localizedDeviceName: DeviceInfo.testValue.localizedModelName
        )
        ApplicationLaunchRecord(
          id: OperationAnalysis.mock2.launchId,
          localizedDeviceName: DeviceInfo.testValue.localizedModelName
        )
      }
    }
  }

  let model = OperationDevToolsModel()

  Button("Present") {
    isPresenting = true
  }
  .sheet(isPresented: $isPresenting) {
    OperationDevToolsView(model: model)
  }
}
