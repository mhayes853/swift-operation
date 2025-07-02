import FoundationModels
import SwiftUI

public struct AIAvailabilitySectionView: View {
  @Environment(\.systemLanguageModelAvailability) var availability

  public var body: some View {
    Section {
      Label {
        HStack {
          switch self.availability {
          case .available:
            Text("Available")
          case .unavailable(.appleIntelligenceNotEnabled):
            Text("Apple Intelligence Not Enabled")
          case .unavailable(.modelNotReady):
            Text("Model Not Ready")
          default:
            Text("Unavailable")
          }
          Spacer()
          AvailabilityCircleView(isAvailable: self.availability == .available)
        }
      } icon: {
        Image(systemName: "bubbles.and.sparkles.fill")
          .symbolRenderingMode(.multicolor)
          .foregroundStyle(Color.accentColor.gradient)
      }

      if self.availability == .unavailable(.appleIntelligenceNotEnabled) {
        Link("Open Settings", destination: settingsURL)
      }
    } header: {
      Text("CanIClimb AI Availability")
    } footer: {
      switch self.availability {
      case .available:
        Text(
          """
          Apple Intelligence is enabled and ready to use on your \(localizedModelName), have fun \
          climbing!
          """
        )
      case .unavailable(.appleIntelligenceNotEnabled):
        Text(
          """
          Apple Intelligence is available for your \(localizedModelName), but it is not enabled. \
          Go to settings and enable Apple Intelligence to access features such as personalized \
          training plans!
          """
        )
      case .unavailable(.modelNotReady):
        Text(
          """
          Apple Intelligence is enabled on your \(localizedModelName), but the model is readying \
          itself. Please wait and check back later.
          """
        )
      default:
        Text("Apple Intelligence is unavailable on your \(localizedModelName).")
      }
    }
  }
}

#Preview {
  NavigationStack {
    Form {
      AIAvailabilitySectionView()
    }
  }
  .environment(\.systemLanguageModelAvailability, .unavailable(.modelNotReady))
}
