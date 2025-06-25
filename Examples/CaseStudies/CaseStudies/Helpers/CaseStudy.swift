import SwiftUI

protocol CaseStudy: View, Identifiable {
  associatedtype Content: View
  
  var title: LocalizedStringKey { get }
  var description: LocalizedStringKey { get }
  
  @ViewBuilder var content: Content { get }
}

extension CaseStudy {
  var id: String {
    String(reflecting: Self.self)
  }
  
  var body: some View {
    Form {
      Section {
        DisclosureGroup {
          Text(self.description)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
          Label(self.title, systemImage: "info.circle.fill")
        }
      }
      
      self.content
    }
    .navigationTitle(self.title)
  }
  
  var anyBody: AnyView {
    AnyView(self.body)
  }
}
