import Dependencies
import SharingQuery
import SwiftUI
import Synchronization

// MARK: - DownloadsCaseStudy

struct DownloadsCaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Dowloads"
  let description: LocalizedStringKey = """
    If your app needs to download a file, you can still do so while reporting on its progress \
    using a query. We'll use the `QueryContinuation` handed to the download query to report the \
    progress of the download from an `AsyncThrowingStream`.

    Additionally, for such expensive queries, you may want to opt out of automatic fetching by \
    using the `disableAutomaticFetching` modifier. Applying this modifier means that your query \
    will only fetch data when you explicitly call `fetch`.
    """

  @SharedQuery(Download.query(for: .hugeFile), animation: .bouncy) private var download

  var content: some View {
    if let download {
      Section {
        HStack {
          Label {
            Text(download.progress.formatted(.percent))
          } icon: {
            if self.$download.isLoading {
              ProgressView()
            } else {
              Image(systemName: "checkmark.circle.fill")
            }
          }
        }
        if let url = download.url {
          Label {
            Text("\(url)")
          } icon: {
            Text("URL")
          }
        }
      } header: {
        Text("Download")
      } footer: {
        if let error = self.$download.error {
          Text(error.localizedDescription).foregroundStyle(.red)
        }
      }
    }

    Section {
      Button {
        Task { try await self.$download.fetch() }
      } label: {
        HStack {
          if self.$download.isLoading {
            ProgressView()
          } else {
            Image(systemName: "square.and.arrow.down")
          }
          Text("Begin 1GB Download")
        }
      }
      .disabled(self.$download.isLoading)
    } footer: {
      Text("The file will automatically be deleted when it finishes downloading.")
    }
  }
}

extension URL {
  fileprivate static let hugeFile = Self(string: "http://ipv4.download.thinkbroadband.com/1GB.zip")!
}

// MARK: - Download

struct Download: Hashable, Sendable {
  let progress: Double
  let url: URL?
}

// MARK: - Query

extension Download {
  static func query(for url: URL) -> some QueryRequest<Self, Query.State> {
    Query(url: url)
      .disableAutomaticFetching()
      .staleWhenNoValue()
  }

  struct Query: QueryRequest, Hashable {
    let url: URL

    func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<Download>
    ) async throws -> Download {
      @Dependency(FileDownloaderKey.self) var downloader
      var download = Download(progress: 0, url: nil)
      for try await progress in downloader.download(from: self.url) {
        continuation.yield(progress)
        download = progress
      }
      return download
    }
  }
}

// MARK: - FileDownloader

protocol FileDownloader: Sendable {
  func download(from url: URL) -> any AsyncSequence<Download, Error>
}

enum FileDownloaderKey: DependencyKey {
  static let liveValue: any FileDownloader = URLSessionDownloader()
}

// MARK: - URLSessionDownloader

final class URLSessionDownloader: NSObject {
  private let session: URLSession
  private let delegate: Delegate

  override init() {
    self.delegate = Delegate()
    let config = URLSessionConfiguration.background(
      withIdentifier: "day.onetask.DownloadsCaseStudy.background"
    )
    self.session = URLSession(configuration: config, delegate: self.delegate, delegateQueue: nil)
    super.init()
  }
}

extension URLSessionDownloader: FileDownloader {
  func download(from url: URL) -> any AsyncSequence<Download, any Error> {
    AsyncThrowingStream<Download, any Error> { continuation in
      self.delegate.continuation.withLock { $0 = continuation }
      let task = self.session.downloadTask(with: url)
      task.resume()
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}

extension URLSessionDownloader {
  private final class Delegate: NSObject, URLSessionDownloadDelegate {
    let continuation = Mutex<AsyncThrowingStream<Download, Error>.Continuation?>(nil)

    func urlSession(
      _ session: URLSession,
      downloadTask: URLSessionDownloadTask,
      didFinishDownloadingTo location: URL
    ) {
      self.continuation.withLock {
        $0?.yield(Download(progress: 1, url: location))
        $0?.finish()
      }
      try? FileManager.default.removeItem(at: location)
    }

    func urlSession(
      _ session: URLSession,
      task: URLSessionTask,
      didCompleteWithError error: (any Error)?
    ) {
      self.continuation.withLock { $0?.finish(throwing: error) }
    }

    func urlSession(
      _ session: URLSession,
      downloadTask: URLSessionDownloadTask,
      didWriteData bytesWritten: Int64,
      totalBytesWritten: Int64,
      totalBytesExpectedToWrite: Int64
    ) {
      self.continuation.withLock {
        _ = $0?.yield(Download(progress: downloadTask.progress.fractionCompleted, url: nil))
      }
    }
  }
}

#Preview {
  NavigationStack {
    DownloadsCaseStudy()
  }
}
