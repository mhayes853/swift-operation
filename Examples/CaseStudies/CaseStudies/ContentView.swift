import Dependencies
import OperationSwiftUI
import SharingOperation
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
  @Dependency(\.defaultOperationClient) private var client

  var body: some View {
    NavigationStack {
      Form {
        Text("Tap on any of the case studies to view the library in action!")
          .font(.headline)

        Section("1 - The Basics (Start Here)") {
          CaseStudyLink(study: BasicSwiftUICaseStudy())
          CaseStudyLink(study: BasicUIKitCaseStudy())
          CaseStudyLink(study: BasicSharingCaseStudy())
        }

        Section("2 - Common Use Cases") {
          CaseStudyLink(study: FormCaseStudy())
          CaseStudyLink(study: DownloadsCaseStudy())
          CaseStudyLink(study: OptimisticUpdatesCaseStudy())
          CaseStudyLink(study: InfiniteScrollingCaseStudy())
        }

        Section("3 - Advanced Use Cases") {
          CaseStudyLink(study: DebouncingCaseStudy())
          CaseStudyLink(study: ReusableRefetchingCaseStudy())
          CaseStudyLink(study: ExpensiveLocalComputationsCaseStudy())
          CaseStudyLink(study: CustomFetchConditionsCaseStudy())
        }
      }
      .navigationTitle("Case Studies")
      .operationClient(self.client)
    }
  }
}

// MARK: - CaseStudyLink

private struct CaseStudyLink<Study: CaseStudy>: View {
  let study: Study

  var body: some View {
    NavigationLink {
      self.study
    } label: {
      VStack(alignment: .leading) {
        Text(self.study.title).font(.headline)
        Text(self.study.description)
          .font(.caption)
          .lineLimit(2)
          .foregroundStyle(.secondary)
      }
    }
  }
}

#Preview {
  ContentView()
}
