#if canImport(Combine) && canImport(ViewInspector)
  import Combine
  import ViewInspector

  @MainActor
  final class Inspection<V>: InspectionEmissary {
    let notice = PassthroughSubject<UInt, Never>()
    var callbacks = [UInt: (V) -> Void]()

    func visit(_ view: V, _ line: UInt) {
      if let callback = callbacks.removeValue(forKey: line) {
        callback(view)
      }
    }
  }
#endif
