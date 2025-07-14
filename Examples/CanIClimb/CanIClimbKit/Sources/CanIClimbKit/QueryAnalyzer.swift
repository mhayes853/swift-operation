import Observation
import SwiftUI
import SwiftUINavigation

// MARK: - QueryAnalyzerModel

@MainActor
@Observable
public final class QueryAnalyzerModel: HashableObject {
  public init() {}
}

// MARK: - QueryAnalyzerView

public struct QueryAnalyzerView: View {
  let model: QueryAnalyzerModel

  public var body: some View {
    Text("TODO")
  }
}
