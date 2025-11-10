import Dependencies
import Foundation
import SwiftUI
import SwiftNavigation
import SharingOperation

// MARK: - BasicUIKitCaseStudy

struct BasicUIKitCaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Basic UIKit"
  let description: LocalizedStringKey = """
    Basic usage of the library using the `@SharedOperation` property wrapper to fetch a random \
    quote from the Dummy JSON API in a UIViewController.
    
    You can use the `@SharedOperation` property wrapper anywhere including `@Observable` models and \
    UIViewController instances.
    """

  var content: some View {
    BasicUIKitViewController.Representable()
      .frame(height: 200)
  }
}

// MARK: - BasicUIKitViewController

final class BasicUIKitViewController: UIViewController {
  @SharedOperation(Quote.$randomQuery) private var quote
  
  private lazy var reloadButton = UIButton(
    type: .system,
    primaryAction: UIAction(title: "Reload Quote") { [weak self] _ in
      Task { @MainActor in try await self?.$quote.fetch() }
    }
  )

  private let statusView = BasicUIKitQuoteStatusView()

  override func viewDidLoad() {
    super.viewDidLoad()

    let title = UILabel()
    title.text = "Random Quote"
    title.font = .boldSystemFont(ofSize: 16)

    let stack = UIStackView(
      arrangedSubviews: [title, self.statusView, self.reloadButton]
    )
    stack.axis = .vertical
    stack.spacing = 20
    stack.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: self.view.topAnchor),
      stack.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
    ])
    
    self.observe { [weak self] in
      guard let self else { return }
      self.statusView.update(with: self.$quote.state)
      self.reloadButton.isEnabled = !self.$quote.isLoading
    }
  }
}

extension BasicUIKitViewController {
  struct Representable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> BasicUIKitViewController {
      BasicUIKitViewController()
    }

    func updateUIViewController(_ vc: BasicUIKitViewController, context: Context) {
    }
  }
}

// MARK: - UIQuoteStatusView

final class BasicUIKitQuoteStatusView: UIView {
  private let indicator = UIActivityIndicatorView(style: .medium)

  func update(with state: QueryState<Quote, any Error>) {
    self.subviews.forEach { $0.removeFromSuperview() }
    self.indicator.stopAnimating()
    switch state.status {
    case .result(.success(let q)):
      self.addQuoteSubview(quote: q)

    case .result(.failure(let error)):
      self.addErrorLabel(error: error)

    default:
      if let quote = state.currentValue {
        self.addQuoteSubview(quote: quote, opacity: 0.5)
      } else {
        self.addLoadingIndicator()
      }
    }
  }

  private func addQuoteSubview(quote: Quote, opacity: CGFloat = 1) {
    let quoteLabel = UILabel()
    quoteLabel.numberOfLines = 0
    quoteLabel.text = quote.content

    let authorLabel = UILabel()
    authorLabel.text = "- \(quote.author)"
    authorLabel.font = .italicSystemFont(ofSize: 14)

    let stack = UIStackView(arrangedSubviews: [quoteLabel, authorLabel])
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .vertical
    stack.distribution = .fill
    stack.alignment = .leading
    stack.alpha = opacity
    self.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: self.trailingAnchor)
    ])
  }

  private func addErrorLabel(error: any Error) {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.numberOfLines = 0
    label.text = error.localizedDescription
    label.textColor = .systemRed
    self.addSubview(label)

    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: self.leadingAnchor),
      label.trailingAnchor.constraint(equalTo: self.trailingAnchor)
    ])
  }

  private func addLoadingIndicator() {
    self.indicator.startAnimating()
    self.addSubview(self.indicator)
  }
}

#Preview {
  let _ = prepareDependencies {
    $0[QuoteRandomLoaderKey.self] = Quote.MockRandomLoader(
      result: .failure(CancellationError()),
      delay: .seconds(1)
    )
  }

  NavigationStack {
    BasicUIKitCaseStudy()
  }
}
