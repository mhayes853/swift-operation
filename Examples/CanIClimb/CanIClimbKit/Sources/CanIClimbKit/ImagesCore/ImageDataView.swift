import Dependencies
import SharingQuery
import SwiftUI

public struct ImageDataView<Content: View>: View {
  @SharedQuery<ImageData.Query.State> private var image: ImageData?
  private let content: (QueryStatus<Image>) -> Content

  public init(url: URL, @ViewBuilder content: @escaping (QueryStatus<Image>) -> Content) {
    self._image = SharedQuery(ImageData.query(for: url))
    self.content = content
  }

  public var body: some View {
    self.content(self.$image.status.mapSuccess { Image(platformImage: $0.image) })
  }
}

#Preview {
  let _ = prepareDependencies {
    $0.defaultDatabase = try! canIClimbDatabase()
    $0.defaultQueryClient = QueryClient(storeCreator: .canIClimb)
    $0[ImageData.LoaderKey.self] = ImageData.FileSystemCachedLoader(
      directoryURL: .temporaryDirectory.appending(path: "images-\(UUID())"),
      transport: URLSession.shared
    )

  }

  let url = URL(string: "https://whypeople.xyz/assets/monad-PhvCeWLi.png")!

  ImageDataView(url: url) { status in
    switch status {
    case .result(.failure(let error)):
      Text("An Error Occured (\(error.localizedDescription))").foregroundStyle(.red)
    case .result(.success(let image)):
      image.resizable().scaledToFit()
    default:
      SpinnerView()
    }
  }
}
