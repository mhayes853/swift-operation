import SwiftUI
import Dependencies
import SharingQuery
import QuerySwiftUI

// MARK: - ContentView

struct ContentView: View {
  @Dependency(\.defaultQueryClient) private var client
  
  var body: some View {
    NavigationStack {
      Form {
        Text("Tap on any of the case studies to view the library in action!")
          .font(.headline)
        
        Section {
          CaseStudyLink(study: BasicSwiftUICaseStudy())
          CaseStudyLink(study: BasicUIKitCaseStudy())
          CaseStudyLink(study: BasicSharingCaseStudy())
        }
      }
      .navigationTitle("Case Studies")
      .queryClient(self.client)
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
