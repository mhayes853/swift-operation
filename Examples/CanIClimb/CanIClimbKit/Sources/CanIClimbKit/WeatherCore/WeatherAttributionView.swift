import SharingOperation
import SwiftUI
import WeatherKit

public struct WeatherAttributionView: View {
  @Environment(\.colorScheme) private var colorScheme
  @SharedOperation(WeatherAttribution.currentQuery) private var attribution

  @ScaledMetric private var height = CGFloat(15)

  public init() {}

  public var body: some View {
    switch self.$attribution.status {
    case .result(.success(let attribution)):
      Link(destination: attribution.legalPageURL) {
        let url =
          self.colorScheme == .dark
          ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL
        ImageDataView(url: url) { status in
          switch status {
          case .result(.success(let image)):
            image
              .resizable()
              .scaledToFit()
              .frame(maxHeight: self.height)
          default:
            SpinnerView()
          }
        }
      }
    default:
      SpinnerView()
    }
  }
}
